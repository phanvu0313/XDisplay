import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

@MainActor
final class H264PreviewEncoder {
    private var compressionSession: VTCompressionSession?
    private var configuredWidth = 0
    private var configuredHeight = 0
    private var configuredFPS = 0

    func encode(
        image: CGImage,
        frameIndex: Int,
        fps: Int
    ) async throws -> EncodedVideoFrame {
        let pixelBuffer = try makePixelBuffer(from: image)
        return try await encode(
            pixelBuffer: pixelBuffer,
            width: image.width,
            height: image.height,
            frameIndex: frameIndex,
            fps: fps
        )
    }

    func encode(
        pixelBuffer: CVPixelBuffer,
        width: Int,
        height: Int,
        frameIndex: Int,
        fps: Int
    ) async throws -> EncodedVideoFrame {
        try prepareIfNeeded(width: width, height: height, fps: fps)
        let presentationTime = CMTime(value: Int64(frameIndex), timescale: CMTimeScale(max(1, fps)))

        return try await withCheckedThrowingContinuation { continuation in
            let context = FrameEncodeContext(
                frameIndex: frameIndex,
                width: width,
                height: height,
                continuation: continuation
            )

            let status = VTCompressionSessionEncodeFrame(
                compressionSession!,
                imageBuffer: pixelBuffer,
                presentationTimeStamp: presentationTime,
                duration: .invalid,
                frameProperties: nil,
                sourceFrameRefcon: Unmanaged.passRetained(context).toOpaque(),
                infoFlagsOut: nil
            )

            if status != noErr {
                Unmanaged.passUnretained(context).release()
                continuation.resume(throwing: EncoderError.encodeFailed(status))
            }
        }
    }

    func reset() {
        if let compressionSession {
            VTCompressionSessionInvalidate(compressionSession)
        }
        compressionSession = nil
        configuredWidth = 0
        configuredHeight = 0
        configuredFPS = 0
    }

    private func prepareIfNeeded(width: Int, height: Int, fps: Int) throws {
        guard compressionSession == nil || width != configuredWidth || height != configuredHeight || fps != configuredFPS else {
            return
        }

        reset()

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: compressionOutputCallback,
            refcon: nil,
            compressionSessionOut: &session
        )

        guard status == noErr, let session else {
            throw EncoderError.sessionCreationFailed(status)
        }

        try setProperty(kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue, on: session)
        try setProperty(kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse, on: session)
        try setProperty(kVTCompressionPropertyKey_AllowTemporalCompression, value: kCFBooleanFalse, on: session)
        try setProperty(kVTCompressionPropertyKey_ExpectedFrameRate, value: fps as CFTypeRef, on: session)
        try setProperty(kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 1 as CFTypeRef, on: session)
        try setProperty(kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 1 as CFTypeRef, on: session)
        try setProperty(
            kVTCompressionPropertyKey_ProfileLevel,
            value: kVTProfileLevel_H264_High_AutoLevel,
            on: session
        )
        try setProperty(
            kVTCompressionPropertyKey_H264EntropyMode,
            value: kVTH264EntropyMode_CABAC,
            on: session
        )

        let bitrate = max(width * height * max(fps, 30) / 2, 80_000_000)
        try setProperty(kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFTypeRef, on: session)
        try setProperty(
            kVTCompressionPropertyKey_DataRateLimits,
            value: [bitrate * 4 / 8, 1] as CFArray,
            on: session
        )
        try setProperty(kVTCompressionPropertyKey_Quality, value: 1.0 as CFTypeRef, on: session)

        let prepareStatus = VTCompressionSessionPrepareToEncodeFrames(session)
        guard prepareStatus == noErr else {
            throw EncoderError.prepareFailed(prepareStatus)
        }

        compressionSession = session
        configuredWidth = width
        configuredHeight = height
        configuredFPS = fps
    }

    private func setProperty(_ key: CFString, value: CFTypeRef, on session: VTCompressionSession) throws {
        let status = VTSessionSetProperty(session, key: key, value: value)
        guard status == noErr else {
            throw EncoderError.propertySetFailed(status)
        }
    }

    private func makePixelBuffer(from image: CGImage) throws -> CVPixelBuffer {
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: image.width,
            kCVPixelBufferHeightKey: image.height
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            image.width,
            image.height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw EncoderError.pixelBufferCreationFailed(status)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard
            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
            let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            )
        else {
            throw EncoderError.renderContextUnavailable
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixelBuffer
    }
}

private final class FrameEncodeContext {
    let frameIndex: Int
    let width: Int
    let height: Int
    let continuation: CheckedContinuation<EncodedVideoFrame, Error>

    init(
        frameIndex: Int,
        width: Int,
        height: Int,
        continuation: CheckedContinuation<EncodedVideoFrame, Error>
    ) {
        self.frameIndex = frameIndex
        self.width = width
        self.height = height
        self.continuation = continuation
    }
}

private let compressionOutputCallback: VTCompressionOutputCallback = { _, sourceFrameRefCon, status, _, sampleBuffer in
    guard let sourceFrameRefCon else { return }
    let context = Unmanaged<FrameEncodeContext>.fromOpaque(sourceFrameRefCon).takeRetainedValue()

    guard status == noErr, let sampleBuffer else {
        context.continuation.resume(throwing: EncoderError.encodeFailed(status))
        return
    }

    do {
        let payload = try makeH264Payload(from: sampleBuffer)
        context.continuation.resume(returning: EncodedVideoFrame(
            frameIndex: context.frameIndex,
            width: context.width,
            height: context.height,
            codec: .h264,
            payload: payload
        ))
    } catch {
        context.continuation.resume(throwing: error)
    }
}

private func makeH264Payload(from sampleBuffer: CMSampleBuffer) throws -> Data {
    guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
        throw EncoderError.sampleDataUnavailable
    }

    let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]]
    let notSync = attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool ?? false
    let isKeyframe = !notSync

    var payload = Data()
    payload.append(1)

    var flags: UInt8 = 0
    if isKeyframe {
        flags |= H264PayloadFlags.keyframe
    }

    var sps = Data()
    var pps = Data()

    if isKeyframe, let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
        sps = try copyParameterSet(at: 0, from: formatDescription)
        pps = try copyParameterSet(at: 1, from: formatDescription)
        flags |= H264PayloadFlags.hasParameterSets
    }

    payload.append(flags)
    payload.appendUInt16(UInt16(sps.count))
    payload.appendUInt16(UInt16(pps.count))
    payload.append(sps)
    payload.append(pps)

    let totalLength = CMBlockBufferGetDataLength(dataBuffer)
    var sampleData = Data(count: totalLength)
    let copyStatus = sampleData.withUnsafeMutableBytes { bytes in
        CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: totalLength, destination: bytes.baseAddress!)
    }

    guard copyStatus == noErr else {
        throw EncoderError.blockBufferCopyFailed(copyStatus)
    }

    payload.append(sampleData)
    return payload
}

private func copyParameterSet(at index: Int, from formatDescription: CMFormatDescription) throws -> Data {
    var pointer: UnsafePointer<UInt8>?
    var length = 0
    var count = 0

    let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
        formatDescription,
        parameterSetIndex: index,
        parameterSetPointerOut: &pointer,
        parameterSetSizeOut: &length,
        parameterSetCountOut: &count,
        nalUnitHeaderLengthOut: nil
    )

    guard status == noErr, let pointer else {
        throw EncoderError.parameterSetUnavailable(status)
    }

    return Data(bytes: pointer, count: length)
}

private enum EncoderError: LocalizedError {
    case sessionCreationFailed(OSStatus)
    case propertySetFailed(OSStatus)
    case prepareFailed(OSStatus)
    case pixelBufferCreationFailed(CVReturn)
    case renderContextUnavailable
    case encodeFailed(OSStatus)
    case sampleDataUnavailable
    case blockBufferCopyFailed(OSStatus)
    case parameterSetUnavailable(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .sessionCreationFailed(status):
            "Unable to create the H.264 compression session (\(status))"
        case let .propertySetFailed(status):
            "Unable to configure the H.264 compression session (\(status))"
        case let .prepareFailed(status):
            "Unable to prepare the H.264 encoder (\(status))"
        case let .pixelBufferCreationFailed(status):
            "Unable to create the encoder pixel buffer (\(status))"
        case .renderContextUnavailable:
            "Unable to draw into the encoder pixel buffer"
        case let .encodeFailed(status):
            "Unable to encode the H.264 frame (\(status))"
        case .sampleDataUnavailable:
            "Encoded H.264 sample data was unavailable"
        case let .blockBufferCopyFailed(status):
            "Unable to copy encoded H.264 bytes (\(status))"
        case let .parameterSetUnavailable(status):
            "Unable to read H.264 parameter sets (\(status))"
        }
    }
}

private enum H264PayloadFlags {
    static let keyframe: UInt8 = 1 << 0
    static let hasParameterSets: UInt8 = 1 << 1
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
