import Foundation
import CoreMedia
import UIKit

final class RemoteDisplayRenderer: @unchecked Sendable {
    final class DecodedVideoFrame: @unchecked Sendable {
        enum Storage {
            case image(UIImage)
            case sampleBuffer(DecodedSampleBuffer)
        }

        let storage: Storage

        private init(storage: Storage) {
            self.storage = storage
        }

        static func image(_ image: UIImage) -> DecodedVideoFrame {
            DecodedVideoFrame(storage: .image(image))
        }

        static func sampleBuffer(_ sampleBuffer: DecodedSampleBuffer) -> DecodedVideoFrame {
            DecodedVideoFrame(storage: .sampleBuffer(sampleBuffer))
        }
    }

    typealias VideoFrameSink = @MainActor @Sendable (DecodedVideoFrame, EncodedVideoFrame) -> Void
    typealias MockFrameSink = @MainActor @Sendable (MockFrameDescriptor) -> Void

    private let decodePipeline = ClientVideoDecodePipeline()
    private let lock = NSLock()
    private var pendingVideoFrame: EncodedVideoFrame?
    private var decodeTask: Task<Void, Never>?
    private var onVideoFrameCommitted: VideoFrameSink?
    private var onMockFrameCommitted: MockFrameSink?
    private(set) var latestFrame: MockFrameDescriptor?

    func prepare() async throws {
    }

    func setVideoFrameSink(_ sink: VideoFrameSink?) {
        lock.lock()
        onVideoFrameCommitted = sink
        lock.unlock()
    }

    func setMockFrameSink(_ sink: MockFrameSink?) {
        lock.lock()
        onMockFrameCommitted = sink
        lock.unlock()
    }

    func display(_ frame: MockFrameDescriptor) {
        let sink: MockFrameSink?
        lock.lock()
        latestFrame = frame
        sink = onMockFrameCommitted
        lock.unlock()

        guard let sink else { return }
        Task { @MainActor in
            sink(frame)
        }
    }

    func display(_ frame: EncodedVideoFrame) {
        lock.lock()
        pendingVideoFrame = frame
        if decodeTask == nil {
            decodeTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                await self.runDecodeLoop()
            }
        }
        lock.unlock()
    }

    func reset() {
        lock.lock()
        let currentDecodeTask = decodeTask
        self.decodeTask = nil
        pendingVideoFrame = nil
        latestFrame = nil
        lock.unlock()

        currentDecodeTask?.cancel()
        decodePipeline.reset()
    }

    private func takePendingFrame() -> EncodedVideoFrame? {
        lock.lock()
        let frame = pendingVideoFrame
        pendingVideoFrame = nil
        lock.unlock()
        return frame
    }

    private func commitDecodedFrame(_ decodedFrame: DecodedVideoFrame, for frame: EncodedVideoFrame) async {
        if let sink = currentSink() {
            await MainActor.run {
                sink(decodedFrame, frame)
            }
        }
    }

    private func finishDecodeLoop() {
        lock.lock()
        decodeTask = nil
        lock.unlock()
    }

    private func runDecodeLoop() async {
        while !Task.isCancelled {
            guard let frame = takePendingFrame() else {
                finishDecodeLoop()
                return
            }

            do {
                let decodedFrame = try await decodePipeline.decode(frame)
                guard !Task.isCancelled else { return }

                await commitDecodedFrame(decodedFrame, for: frame)
            } catch {
                AppLogger.video.error("Failed decoding preview frame on client: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func currentSink() -> VideoFrameSink? {
        lock.lock()
        let sink = onVideoFrameCommitted
        lock.unlock()
        return sink
    }
}

private final class ClientVideoDecodePipeline: @unchecked Sendable {
    private let h264Decoder = H264PreviewDecoder()

    func decode(_ frame: EncodedVideoFrame) async throws -> RemoteDisplayRenderer.DecodedVideoFrame {
        switch frame.codec {
        case .jpeg:
            let decodedImage = autoreleasepool {
                UIImage(data: frame.payload)
            }
            guard let decodedImage else {
                throw ClientVideoDecodeError.jpegDecodeFailed
            }
            return .image(decodedImage)
        case .h264:
            return .sampleBuffer(try await h264Decoder.decode(frame))
        case .hevc:
            throw ClientVideoDecodeError.hevcUnsupported
        }
    }

    func reset() {
        h264Decoder.reset()
    }
}

private enum ClientVideoDecodeError: LocalizedError {
    case jpegDecodeFailed
    case hevcUnsupported

    var errorDescription: String? {
        switch self {
        case .jpegDecodeFailed:
            "Failed to decode JPEG preview image on client"
        case .hevcUnsupported:
            "HEVC preview decode is not implemented on client"
        }
    }
}
