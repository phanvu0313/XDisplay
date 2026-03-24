import Foundation

public actor DisplaySessionController {
    public private(set) var state: DisplaySessionState

    public init(role: SessionRole) {
        state = DisplaySessionState(role: role)
    }

    public func transition(
        to phase: SessionPhase,
        connectionState: ConnectionState,
        statusText: String
    ) {
        state.phase = phase
        state.connectionState = connectionState
        state.statusText = statusText
    }

    public func updateConfiguration(_ configuration: DisplaySessionConfiguration) {
        state.configuration = configuration
    }

    public func snapshot() -> DisplaySessionState {
        state
    }
}
