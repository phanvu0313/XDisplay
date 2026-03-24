import Foundation

public protocol WiredTransportBridge: Sendable {
    func start(sessionID: UUID, role: SessionRole) async throws
    func stop() async
    func sendControl(_ envelope: ControlEnvelope) async throws
    func receiveControlStream() -> AsyncStream<ControlEnvelope>
}

public enum WiredTransportBridgeError: LocalizedError, Equatable {
    case unavailable
    case notAttached
    case unsupportedEnvironment
    case probeFailed(String)
    case tunnelUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "Wired USB transport bridge is not implemented yet."
        case .notAttached:
            "No supported wired client is attached."
        case .unsupportedEnvironment:
            "The current environment does not support the wired transport bridge."
        case let .probeFailed(message):
            message
        case let .tunnelUnavailable(message):
            message
        }
    }
}

public struct UnimplementedWiredTransportBridge: WiredTransportBridge {
    public init() {}

    public func start(sessionID _: UUID, role _: SessionRole) async throws {
        throw WiredTransportBridgeError.unavailable
    }

    public func stop() async {}

    public func sendControl(_: ControlEnvelope) async throws {
        throw WiredTransportBridgeError.unavailable
    }

    public func receiveControlStream() -> AsyncStream<ControlEnvelope> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
