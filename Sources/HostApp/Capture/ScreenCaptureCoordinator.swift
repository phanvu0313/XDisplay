import CoreMedia
import CoreVideo
import Foundation
import ImageIO
@preconcurrency import ScreenCaptureKit
import UniformTypeIdentifiers
import VideoToolbox

@MainActor
final class ScreenCaptureCoordinator {
    private enum PreviewLimits {
        static let maxWidth = 2532
        static let maxHeight = 1170
        static let maxFPS = 60
        static let maxEmptyFrameSkips = 30
    }

    private var frameIndex = 0
    private var cachedDisplay: SCDisplay?
    private var cachedDisplayID: CGDirectDisplayID?
    private var activeStream: SCStream?
    private var activeStreamDisplayID: CGDirectDisplayID?
    private var activeStreamSize: CGSize = .zero
    private var activeStreamFPS = 0
    private var frameRelay: ScreenFrameRelay?
    private var lastPreviewFrame: EncodedVideoFrame?
    private let h264Encoder = H264PreviewEncoder()

    func prepareCapture(
        configuration: DisplaySessionConfiguration = DisplaySessionConfiguration(),
        displayID: CGDirectDisplayID? = nil
    ) async throws {
        let display = try await self.display(matching: displayID)
        let targetSize = fittedSize(
            sourceWidth: display.width,
            sourceHeight: display.height,
            maxWidth: min(configuration.width, PreviewLimits.maxWidth),
            maxHeight: min(configuration.height, PreviewLimits.maxHeight)
        )

        try await prepareRealtimeStream(
            display: display,
            displayID: displayID,
            targetSize: targetSize,
            fps: min(configuration.targetFPS, PreviewLimits.maxFPS)
        )
        AppLogger.video.info("Screen capture pipeline prepared")
    }

    func recoverCapture(
        configuration: DisplaySessionConfiguration = DisplaySessionConfiguration(),
        displayID: CGDirectDisplayID? = nil
    ) async throws {
        await stopActiveStream()
        try await prepareCapture(configuration: configuration, displayID: displayID)
    }

    func stopCapture() async {
        await stopActiveStream()
    }

    func capturePreviewFrame(
        configuration: DisplaySessionConfiguration,
        displayID: CGDirectDisplayID? = nil
    ) async throws -> EncodedVideoFrame {
        let display = try await self.display(matching: displayID)
        let targetSize = fittedSize(
            sourceWidth: display.width,
            sourceHeight: display.height,
            maxWidth: min(configuration.width, PreviewLimits.maxWidth),
            maxHeight: min(configuration.height, PreviewLimits.maxHeight)
        )

        try await prepareRealtimeStream(
            display: display,
            displayID: displayID,
            targetSize: targetSize,
            fps: min(configuration.targetFPS, PreviewLimits.maxFPS)
        )

        guard let frameRelay else {
            throw CaptureError.streamUnavailable
        }

        var pixelBuffer: CVPixelBuffer?
        var skippedFrameCount = 0

        while pixelBuffer == nil {
            let sampleBuffer = try await frameRelay.nextFrame().sampleBuffer
            pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)

            guard pixelBuffer == nil else {
                break
            }

            skippedFrameCount += 1
            AppLogger.video.debug("Skipping ScreenCaptureKit sample without pixel buffer (\(skippedFrameCount, privacy: .public))")

            if skippedFrameCount >= PreviewLimits.maxEmptyFrameSkips {
                if let lastPreviewFrame {
                    AppLogger.video.debug("Reusing last preview frame after \(skippedFrameCount, privacy: .public) empty ScreenCaptureKit samples")
                    let fallbackFrame = EncodedVideoFrame(
                        frameIndex: frameIndex,
                        width: lastPreviewFrame.width,
                        height: lastPreviewFrame.height,
                        codec: lastPreviewFrame.codec,
                        payload: lastPreviewFrame.payload
                    )
                    self.lastPreviewFrame = fallbackFrame
                    return fallbackFrame
                }
                throw CaptureError.imageBufferUnavailable
            }
        }

        defer { frameIndex += 1 }
        guard let pixelBuffer else {
            throw CaptureError.imageBufferUnavailable
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        switch configuration.codec {
        case .jpeg:
            let image = try cgImage(from: pixelBuffer)
            let payload = try encodeJPEG(from: image, quality: jpegQuality(for: configuration.quality))
            let frame = EncodedVideoFrame(
                frameIndex: frameIndex,
                width: width,
                height: height,
                codec: .jpeg,
                payload: payload
            )
            lastPreviewFrame = frame
            return frame
        case .h264:
            let frame = try await h264Encoder.encode(
                pixelBuffer: pixelBuffer,
                width: width,
                height: height,
                frameIndex: frameIndex,
                fps: min(configuration.targetFPS, PreviewLimits.maxFPS),
                qualityPreset: configuration.quality
            )
            lastPreviewFrame = frame
            return frame
        case .hevc:
            throw CaptureError.unsupportedCodec(configuration.codec)
        }
    }

    private func prepareRealtimeStream(
        display: SCDisplay,
        displayID: CGDirectDisplayID?,
        targetSize: CGSize,
        fps: Int
    ) async throws {
        let needsNewStream = activeStream == nil ||
            activeStreamDisplayID != displayID ||
            activeStreamSize != targetSize ||
            activeStreamFPS != fps

        guard needsNewStream else { return }

        await stopActiveStream()

        let relay = ScreenFrameRelay()
        let streamConfiguration = SCStreamConfiguration()
        streamConfiguration.width = Int(targetSize.width)
        streamConfiguration.height = Int(targetSize.height)
        streamConfiguration.showsCursor = true
        streamConfiguration.queueDepth = 5
        streamConfiguration.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfiguration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(1, fps)))

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let stream = SCStream(filter: filter, configuration: streamConfiguration, delegate: relay)
        try stream.addStreamOutput(relay, type: .screen, sampleHandlerQueue: relay.queue)
        try await stream.startCapture()

        frameRelay = relay
        activeStream = stream
        activeStreamDisplayID = displayID
        activeStreamSize = targetSize
        activeStreamFPS = fps
        AppLogger.video.info("Realtime SCStream started for display \(display.displayID) at \(Int(targetSize.width))x\(Int(targetSize.height)) @ \(fps) FPS")
    }

    private func stopActiveStream() async {
        if let activeStream {
            try? await activeStream.stopCapture()
        }

        frameRelay?.finish(with: nil)
        frameRelay = nil
        activeStream = nil
        activeStreamDisplayID = nil
        activeStreamSize = .zero
        activeStreamFPS = 0
    }

    private func display(matching displayID: CGDirectDisplayID?) async throws -> SCDisplay {
        if let cachedDisplay, cachedDisplayID == displayID {
            return cachedDisplay
        }

        let deadline = Date().addingTimeInterval(displayID == nil ? 0 : 5)

        while true {
            let shareableContent: SCShareableContent = try await withCheckedThrowingContinuation { continuation in
                SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let content else {
                        continuation.resume(throwing: CaptureError.shareableContentUnavailable)
                        return
                    }

                    continuation.resume(returning: content)
                }
            }

            let resolvedDisplay: SCDisplay?
            if let displayID {
                resolvedDisplay = shareableContent.displays.first { $0.displayID == displayID }
            } else {
                resolvedDisplay = shareableContent.displays.first
            }

            if let resolvedDisplay {
                cachedDisplay = resolvedDisplay
                cachedDisplayID = displayID
                return resolvedDisplay
            }

            guard Date() < deadline else {
                if let displayID {
                    throw VirtualDisplayError.captureDisplayUnavailable(displayID)
                }
                throw CaptureError.displayUnavailable
            }

            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func fittedSize(sourceWidth: Int, sourceHeight: Int, maxWidth: Int, maxHeight: Int) -> CGSize {
        let widthRatio = CGFloat(maxWidth) / CGFloat(sourceWidth)
        let heightRatio = CGFloat(maxHeight) / CGFloat(sourceHeight)
        let scale = min(widthRatio, heightRatio, 1)

        let scaledWidth = max(2, Int(CGFloat(sourceWidth) * scale))
        let scaledHeight = max(2, Int(CGFloat(sourceHeight) * scale))

        return CGSize(
            width: alignedEvenDimension(scaledWidth),
            height: alignedEvenDimension(scaledHeight)
        )
    }

    private func alignedEvenDimension(_ value: Int) -> Int {
        let evenValue = value.isMultiple(of: 2) ? value : value - 1
        return max(2, evenValue)
    }

    private func cgImage(from pixelBuffer: CVPixelBuffer) throws -> CGImage {
        var image: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        guard status == noErr, let image else {
            throw CaptureError.renderFailed
        }
        return image
    }

    private func encodeJPEG(from image: CGImage, quality: CGFloat) throws -> Data {
        let destinationData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                destinationData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            throw CaptureError.encoderUnavailable
        }

        let options: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary

        CGImageDestinationAddImage(destination, image, options)

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.encodingFailed
        }

        return destinationData as Data
    }

    private func jpegQuality(for preset: StreamQualityPreset) -> CGFloat {
        switch preset {
        case .balanced:
            0.55
        case .sharp:
            0.72
        case .lowLatency:
            0.42
        }
    }
}

private final class ScreenFrameRelay: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.xdisplay.host.capture.stream", qos: .userInteractive)

    private let lock = NSLock()
    private var latestFrame: SampleBufferBox?
    private var waiter: CheckedContinuation<SampleBufferBox, Error>?
    private var terminalError: Error?

    func nextFrame() async throws -> SampleBufferBox {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let terminalError {
                lock.unlock()
                continuation.resume(throwing: terminalError)
                return
            }

            if let latestFrame {
                self.latestFrame = nil
                lock.unlock()
                continuation.resume(returning: latestFrame)
                return
            }

            waiter = continuation
            lock.unlock()
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        finish(with: error)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen, CMSampleBufferIsValid(sampleBuffer) else {
            return
        }

        lock.lock()
        let boxedSampleBuffer = SampleBufferBox(sampleBuffer: sampleBuffer)

        if let waiter {
            self.waiter = nil
            lock.unlock()
            waiter.resume(returning: boxedSampleBuffer)
            return
        }

        latestFrame = boxedSampleBuffer
        lock.unlock()
    }

    func finish(with error: Error?) {
        lock.lock()
        terminalError = error ?? CaptureError.streamStopped
        let waiter = waiter
        self.waiter = nil
        latestFrame = nil
        lock.unlock()

        if let waiter {
            waiter.resume(throwing: terminalError ?? CaptureError.streamStopped)
        }
    }
}

private final class SampleBufferBox: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer

    init(sampleBuffer: CMSampleBuffer) {
        self.sampleBuffer = sampleBuffer
    }
}

private enum CaptureError: LocalizedError {
    case displayUnavailable
    case shareableContentUnavailable
    case streamUnavailable
    case streamStopped
    case imageBufferUnavailable
    case renderFailed
    case encoderUnavailable
    case encodingFailed
    case unsupportedCodec(VideoCodec)

    var errorDescription: String? {
        switch self {
        case .displayUnavailable:
            "Unable to resolve a shareable display for capture"
        case .shareableContentUnavailable:
            "Unable to enumerate shareable screen content"
        case .streamUnavailable:
            "Realtime capture stream is unavailable"
        case .streamStopped:
            "Realtime capture stream stopped unexpectedly"
        case .imageBufferUnavailable:
            "ScreenCaptureKit did not return a pixel buffer"
        case .renderFailed:
            "Unable to render the preview frame"
        case .encoderUnavailable:
            "Unable to create the JPEG encoder"
        case .encodingFailed:
            "Unable to encode the preview frame"
        case let .unsupportedCodec(codec):
            "Preview capture does not support codec \(codec.rawValue) yet"
        }
    }

    var isTransientCaptureFailure: Bool {
        switch self {
        case .streamUnavailable, .streamStopped, .imageBufferUnavailable:
            true
        case .displayUnavailable,
             .shareableContentUnavailable,
             .renderFailed,
             .encoderUnavailable,
             .encodingFailed,
             .unsupportedCodec:
            false
        }
    }
}
