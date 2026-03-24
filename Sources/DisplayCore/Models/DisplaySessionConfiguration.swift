import Foundation

public enum VideoCodec: String, Codable, CaseIterable, Sendable {
    case jpeg
    case h264
    case hevc
}

public enum StreamQualityPreset: String, Codable, CaseIterable, Sendable {
    case balanced
    case sharp
    case lowLatency
}

public struct DisplaySessionConfiguration: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var targetFPS: Int
    public var codec: VideoCodec
    public var quality: StreamQualityPreset

    public init(
        width: Int = 1920,
        height: Int = 1080,
        targetFPS: Int = 60,
        codec: VideoCodec = .h264,
        quality: StreamQualityPreset = .lowLatency
    ) {
        self.width = width
        self.height = height
        self.targetFPS = targetFPS
        self.codec = codec
        self.quality = quality
    }
}
