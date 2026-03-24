import Foundation

public struct MockFrameDescriptor: Codable, Sendable, Equatable {
    public var frameIndex: Int
    public var timestamp: Date
    public var phase: Double
    public var accentHue: Double

    public init(
        frameIndex: Int,
        timestamp: Date = Date(),
        phase: Double,
        accentHue: Double
    ) {
        self.frameIndex = frameIndex
        self.timestamp = timestamp
        self.phase = phase
        self.accentHue = accentHue
    }
}
