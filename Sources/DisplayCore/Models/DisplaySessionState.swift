import Foundation

public enum SessionRole: String, Codable, Sendable {
    case host
    case client
}

public enum ConnectionState: String, Codable, Sendable {
    case idle
    case discovering
    case connected
    case streaming
    case failed
}

public struct DisplaySessionState: Sendable, Equatable {
    public var role: SessionRole
    public var phase: SessionPhase
    public var connectionState: ConnectionState
    public var statusText: String
    public var configuration: DisplaySessionConfiguration

    public init(
        role: SessionRole,
        phase: SessionPhase = .idle,
        connectionState: ConnectionState = .idle,
        statusText: String = "Idle",
        configuration: DisplaySessionConfiguration = .init()
    ) {
        self.role = role
        self.phase = phase
        self.connectionState = connectionState
        self.statusText = statusText
        self.configuration = configuration
    }
}
