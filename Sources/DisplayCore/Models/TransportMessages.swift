import Foundation

public enum SessionErrorCode: String, Codable, Sendable, Equatable {
    case unsupportedProtocol
    case invalidState
    case transportUnavailable
    case internalFailure
}

public struct DeviceDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var model: String

    public init(id: UUID = UUID(), name: String, model: String) {
        self.id = id
        self.name = name
        self.model = model
    }
}

public struct SessionHello: Codable, Equatable, Sendable {
    public var device: DeviceDescriptor
    public var supportedCodecs: [VideoCodec]

    public init(device: DeviceDescriptor, supportedCodecs: [VideoCodec]) {
        self.device = device
        self.supportedCodecs = supportedCodecs
    }
}

public struct EncodedVideoFrame: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var frameIndex: Int
    public var timestamp: Date
    public var width: Int
    public var height: Int
    public var codec: VideoCodec
    public var payload: Data

    public init(
        id: UUID = UUID(),
        frameIndex: Int,
        timestamp: Date = Date(),
        width: Int,
        height: Int,
        codec: VideoCodec,
        payload: Data
    ) {
        self.id = id
        self.frameIndex = frameIndex
        self.timestamp = timestamp
        self.width = width
        self.height = height
        self.codec = codec
        self.payload = payload
    }
}

public struct ControlEnvelope: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sessionID: UUID
    public let protocolVersion: Int
    public let senderRole: SessionRole
    public let sentAt: Date
    public let message: ControlMessage

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        protocolVersion: Int = 1,
        senderRole: SessionRole,
        sentAt: Date = Date(),
        message: ControlMessage
    ) {
        self.id = id
        self.sessionID = sessionID
        self.protocolVersion = protocolVersion
        self.senderRole = senderRole
        self.sentAt = sentAt
        self.message = message
    }
}

public enum ControlMessage: Codable, Sendable, Equatable {
    case hello(SessionHello)
    case negotiate(DisplaySessionConfiguration)
    case configurationAccepted(DisplaySessionConfiguration)
    case peerReady
    case startStream
    case videoFrame(EncodedVideoFrame)
    case mockFrame(MockFrameDescriptor)
    case stopStream
    case heartbeat(Date)
    case error(SessionErrorCode, String)
}
