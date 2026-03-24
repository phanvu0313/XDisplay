import CoreMedia
import Foundation
import VideoToolbox

final class DecodedSampleBuffer: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer

    init(sampleBuffer: CMSampleBuffer) {
        self.sampleBuffer = sampleBuffer
    }
}

final class H264PreviewDecoder: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.xdisplay.h264-decoder", qos: .userInitiated)
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    private var firstFrameTimestamp: Date?
    private var lastFrameTimestamp: Date?
    private var lastPresentationTime: CMTime = .zero

    func decode(_ frame: EncodedVideoFrame) async throws -> DecodedSampleBuffer {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.decodeSync(frame, continuation: continuation)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func reset() {
        queue.sync {
            if let decompressionSession {
                VTDecompressionSessionInvalidate(decompressionSession)
            }
            decompressionSession = nil
            formatDescription = nil
            firstFrameTimestamp = nil
            lastFrameTimestamp = nil
            lastPresentationTime = .zero
        }
    }

    private func decodeSync(
        _ frame: EncodedVideoFrame,
        continuation: CheckedContinuation<DecodedSampleBuffer, Error>
    ) throws {
        let parsedPayload = try ParsedPayload(data: frame.payload)

        if parsedPayload.hasParameterSets {
            try updateFormatDescription(sps: parsedPayload.sps, pps: parsedPayload.pps)
        }

        guard let formatDescription else {
            throw DecoderError.missingFormatDescription
        }

        try recreateSessionIfNeeded(formatDescription: formatDescription)
        let sampleBuffer = try makeSampleBuffer(
            sampleData: parsedPayload.sampleData,
            formatDescription: formatDescription
        )
        try decodeImage(sampleBuffer: sampleBuffer, frame: frame, continuation: continuation)
    }

    private func updateFormatDescription(sps: Data, pps: Data) throws {
        var formatDescription: CMFormatDescription?

        let status = try sps.withUnsafeBytes { spsRawBuffer in
            try pps.withUnsafeBytes { ppsRawBuffer in
                guard
                    let spsPointer = spsRawBuffer.bindMemory(to: UInt8.self).baseAddress,
                    let ppsPointer = ppsRawBuffer.bindMemory(to: UInt8.self).baseAddress
                else {
                    throw DecoderError.invalidParameterSets
                }

                let parameterSetPointers = [spsPointer, ppsPointer]
                let parameterSetSizes = [sps.count, pps.count]

                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: 2,
                    parameterSetPointers: parameterSetPointers,
                    parameterSetSizes: parameterSetSizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &formatDescription
                )
            }
        }

        guard status == noErr, let videoFormatDescription = formatDescription else {
            throw DecoderError.formatDescriptionCreationFailed(status)
        }

        self.formatDescription = videoFormatDescription
    }

    private func recreateSessionIfNeeded(formatDescription: CMVideoFormatDescription) throws {
        if let decompressionSession {
            let currentDescription = self.formatDescription
            if currentDescription == formatDescription {
                return
            }
            VTDecompressionSessionInvalidate(decompressionSession)
            self.decompressionSession = nil
        }

        let imageBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA
        ]

        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: nil,
            imageBufferAttributes: imageBufferAttributes as CFDictionary,
            outputCallback: nil,
            decompressionSessionOut: &session
        )

        guard status == noErr, let session else {
            throw DecoderError.sessionCreationFailed(status)
        }

        decompressionSession = session
    }

    private func makeSampleBuffer(sampleData: Data, formatDescription: CMVideoFormatDescription) throws -> CMSampleBuffer {
        var blockBuffer: CMBlockBuffer?
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: sampleData.count,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: sampleData.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard blockStatus == kCMBlockBufferNoErr, let blockBuffer else {
            throw DecoderError.blockBufferCreationFailed(blockStatus)
        }

        let replaceStatus = sampleData.withUnsafeBytes { rawBuffer in
            CMBlockBufferReplaceDataBytes(
                with: rawBuffer.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: sampleData.count
            )
        }

        guard replaceStatus == noErr else {
            throw DecoderError.blockBufferFillFailed(replaceStatus)
        }

        var sampleBuffer: CMSampleBuffer?
        var sampleSize = sampleData.count
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr, let sampleBuffer else {
            throw DecoderError.sampleBufferCreationFailed(sampleStatus)
        }

        return sampleBuffer
    }

    private func decodeImage(
        sampleBuffer: CMSampleBuffer,
        frame: EncodedVideoFrame,
        continuation: CheckedContinuation<DecodedSampleBuffer, Error>
    ) throws {
        var infoFlags = VTDecodeInfoFlags()
        let status = VTDecompressionSessionDecodeFrame(
            decompressionSession!,
            sampleBuffer: sampleBuffer,
            flags: [._EnableAsynchronousDecompression],
            infoFlagsOut: &infoFlags
        ) { [self] status, _, imageBuffer, _, _ in
            guard status == noErr, let imageBuffer else {
                continuation.resume(throwing: DecoderError.decodeFailed(status))
                return
            }

            do {
                let outputSampleBuffer = try self.makeImageSampleBuffer(
                    from: imageBuffer,
                    frameTimestamp: frame.timestamp
                )
                continuation.resume(returning: DecodedSampleBuffer(sampleBuffer: outputSampleBuffer))
            } catch {
                continuation.resume(throwing: error)
            }
        }

        guard status == noErr else {
            continuation.resume(throwing: DecoderError.decodeFailed(status))
            return
        }
    }

    private func makeImageSampleBuffer(
        from imageBuffer: CVImageBuffer,
        frameTimestamp: Date
    ) throws -> CMSampleBuffer {
        var imageFormatDescription: CMVideoFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &imageFormatDescription
        )

        guard formatStatus == noErr, let imageFormatDescription else {
            throw DecoderError.imageFormatDescriptionCreationFailed(formatStatus)
        }

        var timing = makeSampleTiming(for: frameTimestamp)

        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescription: imageFormatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr, let sampleBuffer else {
            throw DecoderError.imageSampleBufferCreationFailed(sampleStatus)
        }

        return sampleBuffer
    }

    private func makeSampleTiming(for timestamp: Date) -> CMSampleTimingInfo {
        let defaultDuration = CMTime(value: 1, timescale: 60)

        defer {
            if firstFrameTimestamp == nil {
                firstFrameTimestamp = timestamp
            }
            lastFrameTimestamp = timestamp
        }

        guard let firstFrameTimestamp else {
            lastPresentationTime = .zero
            return CMSampleTimingInfo(
                duration: defaultDuration,
                presentationTimeStamp: .zero,
                decodeTimeStamp: .invalid
            )
        }

        let rawDelta = timestamp.timeIntervalSince(lastFrameTimestamp ?? firstFrameTimestamp)
        let clampedDelta = min(max(rawDelta, 1.0 / 120.0), 1.0 / 24.0)
        let duration = CMTime(seconds: clampedDelta, preferredTimescale: 600)
        let presentationTime = lastPresentationTime + duration
        lastPresentationTime = presentationTime

        return CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
    }
}

private struct ParsedPayload {
    let hasParameterSets: Bool
    let sps: Data
    let pps: Data
    let sampleData: Data

    init(data: Data) throws {
        guard data.count >= 6 else {
            throw DecoderError.invalidPayload
        }

        let flags = data[1]
        hasParameterSets = (flags & H264PayloadFlags.hasParameterSets) != 0

        let spsLength = Int(data.readUInt16(at: 2))
        let ppsLength = Int(data.readUInt16(at: 4))
        let spsStart = 6
        let spsEnd = spsStart + spsLength
        let ppsStart = spsEnd
        let ppsEnd = ppsStart + ppsLength

        guard data.count >= ppsEnd else {
            throw DecoderError.invalidPayload
        }

        sps = data.subdata(in: spsStart..<spsEnd)
        pps = data.subdata(in: ppsStart..<ppsEnd)
        sampleData = data.subdata(in: ppsEnd..<data.count)
    }
}

private enum DecoderError: LocalizedError {
    case invalidPayload
    case invalidParameterSets
    case missingFormatDescription
    case formatDescriptionCreationFailed(OSStatus)
    case sessionCreationFailed(OSStatus)
    case blockBufferCreationFailed(OSStatus)
    case blockBufferFillFailed(OSStatus)
    case sampleBufferCreationFailed(OSStatus)
    case decodeFailed(OSStatus)
    case imageFormatDescriptionCreationFailed(OSStatus)
    case imageSampleBufferCreationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            "Received an invalid H.264 payload"
        case .invalidParameterSets:
            "Received invalid H.264 parameter sets"
        case .missingFormatDescription:
            "The H.264 decoder has not received SPS/PPS yet"
        case let .formatDescriptionCreationFailed(status):
            "Unable to build the H.264 format description (\(status))"
        case let .sessionCreationFailed(status):
            "Unable to create the H.264 decode session (\(status))"
        case let .blockBufferCreationFailed(status):
            "Unable to allocate the H.264 sample buffer (\(status))"
        case let .blockBufferFillFailed(status):
            "Unable to fill the H.264 sample buffer (\(status))"
        case let .sampleBufferCreationFailed(status):
            "Unable to create the H.264 CMSampleBuffer (\(status))"
        case let .decodeFailed(status):
            "Unable to decode the H.264 frame (\(status))"
        case let .imageFormatDescriptionCreationFailed(status):
            "Unable to create an image format description for the decoded frame (\(status))"
        case let .imageSampleBufferCreationFailed(status):
            "Unable to create an image sample buffer for display (\(status))"
        }
    }
}

private enum H264PayloadFlags {
    static let keyframe: UInt8 = 1 << 0
    static let hasParameterSets: UInt8 = 1 << 1
}

private extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        let range = offset..<(offset + 2)
        return subdata(in: range).withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: UInt16.self).bigEndian
        }
    }
}
