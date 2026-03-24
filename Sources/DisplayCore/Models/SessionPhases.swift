import Foundation

public enum SessionPhase: String, Codable, Sendable {
    case idle
    case preparing
    case listening
    case connecting
    case handshaking
    case ready
    case streaming
    case stopping
    case failed
}
