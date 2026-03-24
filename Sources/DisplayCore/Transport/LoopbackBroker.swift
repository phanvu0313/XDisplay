import Foundation

actor LoopbackBroker {
    static let shared = LoopbackBroker()

    private var continuations: [SessionRole: AsyncStream<ControlEnvelope>.Continuation] = [:]
    private var pendingEnvelopes: [SessionRole: [ControlEnvelope]] = [:]

    func register(role: SessionRole, continuation: AsyncStream<ControlEnvelope>.Continuation) {
        continuations[role] = continuation

        let queued = pendingEnvelopes[role] ?? []
        for envelope in queued {
            continuation.yield(envelope)
        }
        pendingEnvelopes[role] = []
    }

    func unregister(role: SessionRole) {
        continuations[role]?.finish()
        continuations[role] = nil
    }

    func send(_ envelope: ControlEnvelope, from role: SessionRole) {
        let receiver: SessionRole = role == .host ? .client : .host

        if let continuation = continuations[receiver] {
            continuation.yield(envelope)
            return
        }

        pendingEnvelopes[receiver, default: []].append(envelope)
    }
}
