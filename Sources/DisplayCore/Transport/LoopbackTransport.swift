import Foundation

public final class LoopbackTransport: @unchecked Sendable, Transport {
    public let mode: TransportMode = .loopback
    private let broker = LoopbackBroker.shared
    private var sessionID: UUID?
    private var role: SessionRole?
    private var stream: AsyncStream<ControlEnvelope>?
    private var continuation: AsyncStream<ControlEnvelope>.Continuation?

    public init() {}

    public func start(sessionID: UUID, role: SessionRole) async throws {
        self.sessionID = sessionID
        self.role = role

        let stream = AsyncStream<ControlEnvelope> { continuation in
            self.continuation = continuation
            Task {
                await self.broker.register(role: role, continuation: continuation)
            }
        }
        self.stream = stream

        AppLogger.transport.info("Loopback transport started")
    }

    public func stop() async {
        if let role {
            await broker.unregister(role: role)
        }
        continuation = nil
        stream = nil
        AppLogger.transport.info("Loopback transport stopped")
    }

    public func send(_ message: ControlMessage) async throws {
        guard let sessionID, let role else {
            throw TransportError.notStarted
        }

        let envelope = ControlEnvelope(
            sessionID: sessionID,
            senderRole: role,
            message: message
        )
        await broker.send(envelope, from: role)
        AppLogger.transport.debug("Loopback message sent: \(String(describing: message), privacy: .public)")
    }

    public func receiveStream() -> AsyncStream<ControlEnvelope> {
        stream ?? AsyncStream { continuation in
            continuation.finish()
        }
    }
}
