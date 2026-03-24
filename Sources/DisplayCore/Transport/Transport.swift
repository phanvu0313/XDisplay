import Foundation

public enum TransportMode: String, Codable, Sendable {
    case loopback
    case network
    case wiredUSB
}

public protocol Transport: Sendable {
    var mode: TransportMode { get }
    func start(sessionID: UUID, role: SessionRole) async throws
    func stop() async
    func send(_ message: ControlMessage) async throws
    func receiveStream() -> AsyncStream<ControlEnvelope>
}

public struct TransportFactory {
    private let wiredBridgeFactory: WiredTransportBridgeFactory

    public init(wiredBridgeFactory: WiredTransportBridgeFactory = WiredTransportBridgeFactory()) {
        self.wiredBridgeFactory = wiredBridgeFactory
    }

    public func makeTransport(mode: TransportMode) -> any Transport {
        switch mode {
        case .loopback:
            LoopbackTransport()
        case .network:
            NetworkTransport()
        case .wiredUSB:
            WiredTransport(bridge: wiredBridgeFactory.makeBridge())
        }
    }
}
