import Foundation

public final class WiredTransport: @unchecked Sendable, Transport {
    public let mode: TransportMode = .wiredUSB
    private let bridge: any WiredTransportBridge
    private var sessionID: UUID?
    private var role: SessionRole?

    public init(bridge: any WiredTransportBridge = UnimplementedWiredTransportBridge()) {
        self.bridge = bridge
    }

    public func start(sessionID: UUID, role: SessionRole) async throws {
        do {
            try await bridge.start(sessionID: sessionID, role: role)
            self.sessionID = sessionID
            self.role = role
            AppLogger.transport.info("Wired transport bridge started")
        } catch let error as WiredTransportBridgeError {
            AppLogger.transport.error("Wired transport bridge failed: \(error.localizedDescription, privacy: .public)")
            throw error
        } catch {
            AppLogger.transport.error("Wired transport startup failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    public func stop() async {
        await bridge.stop()
        sessionID = nil
        role = nil
        AppLogger.transport.info("Wired transport bridge stopped")
    }

    public func send(_ message: ControlMessage) async throws {
        guard let sessionID, let role else {
            throw TransportError.notStarted
        }

        let envelope = ControlEnvelope(
            sessionID: sessionID,
            protocolVersion: SessionRuntime.protocolVersion,
            senderRole: role,
            message: message
        )
        try await bridge.sendControl(envelope)
    }

    public func receiveStream() -> AsyncStream<ControlEnvelope> {
        bridge.receiveControlStream()
    }
}
