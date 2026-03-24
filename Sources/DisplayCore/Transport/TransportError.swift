import Foundation

public enum TransportError: LocalizedError, Sendable {
    case notStarted
    case connectionUnavailable
    case receiveFailed
    case wiredBridgeUnavailable

    public var errorDescription: String? {
        switch self {
        case .notStarted:
            "Transport has not been started."
        case .connectionUnavailable:
            "Transport connection is unavailable."
        case .receiveFailed:
            "Transport receive failed."
        case .wiredBridgeUnavailable:
            "Wired USB transport bridge is not implemented yet."
        }
    }
}
