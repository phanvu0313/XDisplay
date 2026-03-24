import Foundation

public protocol FrameCapturePipeline: Sendable {
    func prepare(configuration: DisplaySessionConfiguration) async throws
}

public protocol VideoEncodingPipeline: Sendable {
    func prepare(configuration: DisplaySessionConfiguration) async throws
}

public protocol VideoDecodingPipeline: Sendable {
    func prepare(configuration: DisplaySessionConfiguration) async throws
}

public enum VideoPipelineError: LocalizedError, Equatable {
    case captureUnavailable
    case encoderUnavailable
    case decoderUnavailable

    public var errorDescription: String? {
        switch self {
        case .captureUnavailable:
            "Frame capture pipeline is not implemented for the real display path yet."
        case .encoderUnavailable:
            "Video encoder pipeline is not implemented yet."
        case .decoderUnavailable:
            "Video decoder pipeline is not implemented yet."
        }
    }
}

public struct UnimplementedFrameCapturePipeline: FrameCapturePipeline {
    public init() {}

    public func prepare(configuration _: DisplaySessionConfiguration) async throws {
        throw VideoPipelineError.captureUnavailable
    }
}

public struct UnimplementedVideoEncodingPipeline: VideoEncodingPipeline {
    public init() {}

    public func prepare(configuration _: DisplaySessionConfiguration) async throws {
        throw VideoPipelineError.encoderUnavailable
    }
}

public struct UnimplementedVideoDecodingPipeline: VideoDecodingPipeline {
    public init() {}

    public func prepare(configuration _: DisplaySessionConfiguration) async throws {
        throw VideoPipelineError.decoderUnavailable
    }
}
