import Foundation
import Observation

@MainActor
@Observable
final class ClientViewerViewModel {
    private let sessionController = DisplaySessionController(role: .client)
    private let transportFactory = TransportFactory()
    private let renderer = RemoteDisplayRenderer()
    private let sessionID = SessionRuntime.makeDefaultSessionID()
    private let localDevice = DeviceDescriptor(name: "iPhone Client", model: "iPhone")

    private(set) var state = DisplaySessionState(
        role: .client,
        statusText: "Waiting for host"
    )
    var selectedTransportMode: TransportMode = .wiredUSB
    var displayScaleMode: ClientDisplayScaleMode = .fill
    private(set) var eventLog: [EventLogEntry] = []
    private(set) var latestFrame: MockFrameDescriptor?
    private var transport: (any Transport)?
    private var receiveTask: Task<Void, Never>?

    init() {
        renderer.setMockFrameSink { [weak self] frame in
            self?.latestFrame = frame
        }
    }

    var displayRenderer: RemoteDisplayRenderer {
        renderer
    }

    var isDisplayPresented: Bool {
        state.connectionState == .streaming
    }

    func connect() async {
        switch state.connectionState {
        case .discovering, .connected, .streaming:
            return
        case .idle, .failed:
            break
        }

        await transport?.stop()
        receiveTask?.cancel()
        receiveTask = nil
        renderer.reset()
        latestFrame = nil
        try? await Task.sleep(for: .milliseconds(250))

        let connectingStatus = "Preparing cable session"

        await sessionController.transition(
            to: .connecting,
            connectionState: .discovering,
            statusText: connectingStatus
        )
        state = await sessionController.snapshot()
        appendLog("Preparing client viewer")

        do {
            let transport = transportFactory.makeTransport(mode: selectedTransportMode)
            self.transport = transport

            try await transport.start(sessionID: sessionID, role: .client)
            startReceivingMessages(from: transport)
            try await renderer.prepare()
            try await transport.send(
                .hello(SessionHello(device: localDevice, supportedCodecs: VideoCodec.allCases))
            )

            await sessionController.transition(
                to: .listening,
                connectionState: .connected,
                statusText: "Waiting for host"
            )
            state = await sessionController.snapshot()
        } catch {
            if let bridgeError = error as? WiredTransportBridgeError {
                appendLog("Cable bridge blocked: \(bridgeError.localizedDescription)")
            }
            appendLog("Client failed: \(error.localizedDescription)")
            await sessionController.transition(
                to: .failed,
                connectionState: .failed,
                statusText: error.localizedDescription
            )
            state = await sessionController.snapshot()
        }
    }
    private func startReceivingMessages(from transport: any Transport) {
        receiveTask?.cancel()
        let renderer = renderer
        receiveTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            for await envelope in transport.receiveStream() {
                guard envelope.protocolVersion == SessionRuntime.protocolVersion else {
                    await self.handleProtocolMismatch(envelope.protocolVersion)
                    continue
                }

                switch envelope.message {
                case let .videoFrame(frame):
                    renderer.display(frame)
                case let .mockFrame(frame):
                    renderer.display(frame)
                default:
                    await self.handleControlEnvelope(envelope)
                }
            }

        AppLogger.transport.info("Client transport stream ended")

            guard !Task.isCancelled else {
                return
            }

            await self.handleTransportEnded()
        }
    }

    private func handleProtocolMismatch(_ version: Int) {
        appendLog("Unsupported protocol version \(version)")
    }

    private func handleControlEnvelope(_ envelope: ControlEnvelope) async {
        switch envelope.message {
        case let .hello(hello):
            appendLog("Host hello from \(hello.device.name)")
            await sessionController.transition(
                to: .handshaking,
                connectionState: .connected,
                statusText: "Negotiating with \(hello.device.name)"
            )
        case let .negotiate(configuration):
            appendLog("Host proposed \(configuration.width)x\(configuration.height) @ \(configuration.targetFPS) codec \(configuration.codec.rawValue)")
            await sessionController.updateConfiguration(configuration)

            if let transport {
                do {
                    try await transport.send(.configurationAccepted(configuration))
                    try await transport.send(.peerReady)
                } catch {
                    appendLog("Failed to respond to negotiation: \(error.localizedDescription)")
                }
            }

            await sessionController.transition(
                to: .ready,
                connectionState: .connected,
                statusText: "Configuration accepted"
            )
        case .startStream:
            appendLog("Host started stream")
            await sessionController.transition(
                to: .streaming,
                connectionState: .streaming,
                statusText: "Streaming started"
            )
        case .videoFrame, .mockFrame:
            break
        case .stopStream:
            appendLog("Host stopped stream")
            renderer.reset()
            await sessionController.transition(
                to: .idle,
                connectionState: .idle,
                statusText: "Ready"
            )
        case let .heartbeat(date):
            appendLog("Heartbeat from host at \(date.formatted(date: .omitted, time: .standard))")
        case let .error(code, message):
            appendLog("Host error \(code.rawValue): \(message)")
            renderer.reset()
            await sessionController.transition(
                to: .failed,
                connectionState: .failed,
                statusText: message
            )
        case let .configurationAccepted(configuration):
            appendLog("Unexpected accepted configuration \(configuration.width)x\(configuration.height)")
        case .peerReady:
            appendLog("Unexpected peerReady on client")
        }

        state = await sessionController.snapshot()
    }

    private func handleTransportEnded() async {
        let snapshot = await sessionController.snapshot()
        guard snapshot.connectionState != .idle, snapshot.connectionState != .failed else {
            return
        }

        renderer.reset()
        latestFrame = nil
        transport = nil
        receiveTask = nil
        appendLog("Connection ended")
        await sessionController.transition(
            to: .idle,
            connectionState: .idle,
            statusText: "Ready"
        )
        state = await sessionController.snapshot()
    }

    private func appendLog(_ message: String) {
        eventLog.insert(EventLogEntry(message: message), at: 0)
        if eventLog.count > 20 {
            eventLog.removeLast(eventLog.count - 20)
        }
    }
}
