import Foundation
import Observation

@MainActor
@Observable
final class HostDashboardViewModel {
    private let permissionCoordinator = ScreenCapturePermissionCoordinator()
    private let sessionController = DisplaySessionController(role: .host)
    private let captureCoordinator = ScreenCaptureCoordinator()
    private let virtualDisplayManager = VirtualDisplayManager()
    private let extendedDisplayGuideWindowController = ExtendedDisplayGuideWindowController()
    private let transportFactory = TransportFactory()
    private let frameCapturePipeline: any FrameCapturePipeline
    private let videoEncodingPipeline: any VideoEncodingPipeline
    private let sessionID = SessionRuntime.makeDefaultSessionID()
    private let localDevice = DeviceDescriptor(name: Host.current().localizedName ?? "Mac", model: "macOS Host")

    private(set) var state = DisplaySessionState(role: .host)
    private(set) var selectedTransportMode: TransportMode = .wiredUSB
    var selectedPerformanceProfile: HostPerformanceProfile = .balanced
    var selectedResolutionOption: HostResolutionOption = .native
    private(set) var eventLog: [EventLogEntry] = []
    private var transport: (any Transport)?
    private var receiveTask: Task<Void, Never>?
    private var mockStreamTask: Task<Void, Never>?
    private var wiredControlPlaneReady = false
    private var hasLoggedFirstPreviewFrame = false
    private var sentPreviewFrameCount = 0
    private var activeCaptureDisplayID: UInt32?
    private(set) var connectedClientDevice: DeviceDescriptor?
    private(set) var lastConnectedAt: Date?

    var selectedProfileSummary: String {
        selectedPerformanceProfile.summary
    }

    var selectedResolutionSummary: String {
        selectedResolutionOption.summary
    }

    var visibleEventLog: [EventLogEntry] {
        eventLog.filter(\.isImportantEvent)
    }

    var isStreamingOrPreparing: Bool {
        switch state.connectionState {
        case .discovering, .connected, .streaming:
            true
        case .idle, .failed:
            false
        }
    }

    init(
        frameCapturePipeline: any FrameCapturePipeline = UnimplementedFrameCapturePipeline(),
        videoEncodingPipeline: any VideoEncodingPipeline = UnimplementedVideoEncodingPipeline()
    ) {
        self.frameCapturePipeline = frameCapturePipeline
        self.videoEncodingPipeline = videoEncodingPipeline
    }

    func startSession() async {
        let sessionConfiguration = preferredConfiguration(for: selectedTransportMode)
        let preparingStatus = "Preparing wired display"

        await sessionController.updateConfiguration(sessionConfiguration)
        await sessionController.transition(
            to: .preparing,
            connectionState: .discovering,
            statusText: preparingStatus
        )
        state = await sessionController.snapshot()
        appendLog("Preparing host session")

        do {
            try permissionCoordinator.authorizeIfNeeded()
            appendLog("Session configuration: \(sessionConfiguration.width)x\(sessionConfiguration.height) @ \(sessionConfiguration.targetFPS) codec \(sessionConfiguration.codec.rawValue)")

            let transport = transportFactory.makeTransport(mode: selectedTransportMode)
            self.transport = transport
            wiredControlPlaneReady = false
            activeCaptureDisplayID = nil
            connectedClientDevice = nil
            lastConnectedAt = nil

            try await transport.start(sessionID: sessionID, role: .host)
            startReceivingMessages(from: transport)

            let displayID = try await virtualDisplayManager.prepareVirtualDisplay(
                configuration: sessionConfiguration
            )
            activeCaptureDisplayID = displayID
            try await captureCoordinator.prepareCapture(
                configuration: sessionConfiguration,
                displayID: displayID
            )
            extendedDisplayGuideWindowController.show(on: displayID, configuration: sessionConfiguration)
            appendLog("Virtual display ready")
            appendLog("Wired control plane ready")

            try await transport.send(
                .hello(SessionHello(device: localDevice, supportedCodecs: VideoCodec.allCases))
            )
            try await transport.send(.negotiate(sessionConfiguration))

            await sessionController.transition(
                to: .listening,
                connectionState: .connected,
                statusText: "Waiting for iPhone"
            )
            state = await sessionController.snapshot()
        } catch {
            extendedDisplayGuideWindowController.hide()
            if let permissionError = error as? ScreenCapturePermissionError {
                switch permissionError {
                case .denied:
                    appendLog("Screen Recording permission missing")
                case .restartRequired:
                    appendLog("Screen Recording granted. Relaunch XDisplayHost before starting again")
                }
            }
            if let bridgeError = error as? WiredTransportBridgeError {
                appendLog("Cable bridge blocked: \(bridgeError.localizedDescription)")
            }
            if let virtualDisplayError = error as? VirtualDisplayError {
                appendLog("Virtual display blocked: \(virtualDisplayError.localizedDescription)")
            }
            if let videoPipelineError = error as? VideoPipelineError {
                appendLog("Video pipeline blocked: \(videoPipelineError.localizedDescription)")
            }
            await transport?.stop()
            appendLog("Host failed: \(error.localizedDescription)")
            await sessionController.transition(
                to: .failed,
                connectionState: .failed,
                statusText: error.localizedDescription
            )
            state = await sessionController.snapshot()
        }
    }

    func stopSession() async {
        mockStreamTask?.cancel()
        receiveTask?.cancel()
        mockStreamTask = nil
        receiveTask = nil

        if let transport {
            try? await transport.send(.stopStream)
            try? await Task.sleep(for: .milliseconds(180))
            await transport.stop()
        }

        await captureCoordinator.stopCapture()
        extendedDisplayGuideWindowController.hide()
        transport = nil
        activeCaptureDisplayID = nil
        wiredControlPlaneReady = false
        hasLoggedFirstPreviewFrame = false
        sentPreviewFrameCount = 0
        connectedClientDevice = nil
        appendLog("Session stopped")
        await sessionController.transition(
            to: .idle,
            connectionState: .idle,
            statusText: "Ready"
        )
        state = await sessionController.snapshot()
    }

    private func startReceivingMessages(from transport: any Transport) {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }

            for await envelope in transport.receiveStream() {
                await self.handleIncomingEnvelope(envelope)
            }

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self.appendLog("Host transport stream ended")
            }
        }
    }

    private func handleIncomingEnvelope(_ envelope: ControlEnvelope) async {
        guard envelope.protocolVersion == SessionRuntime.protocolVersion else {
            appendLog("Received unsupported protocol version \(envelope.protocolVersion)")
            return
        }

        switch envelope.message {
        case let .hello(hello):
            appendLog("Client hello from \(hello.device.name)")
            wiredControlPlaneReady = true
            connectedClientDevice = hello.device
            lastConnectedAt = Date()
            await sessionController.transition(
                to: .handshaking,
                connectionState: .connected,
                statusText: "Negotiating with \(hello.device.name)"
            )
        case let .configurationAccepted(configuration):
            appendLog("Client accepted \(configuration.width)x\(configuration.height) @ \(configuration.targetFPS) codec \(configuration.codec.rawValue)")
            await sessionController.transition(
                to: .ready,
                connectionState: .connected,
                statusText: "Client accepted stream configuration"
            )
            if let transport {
                do {
                    try await transport.send(.startStream)
                    startPreviewStream(over: transport)
                    await sessionController.transition(
                        to: .streaming,
                        connectionState: .streaming,
                        statusText: "Streaming to iPhone"
                    )
                    appendLog("Cable stream started")
                } catch {
                    appendLog("Failed to send startStream: \(error.localizedDescription)")
                }
            }
        case .peerReady:
            appendLog("Client renderer ready")
        case .startStream:
            appendLog("Unexpected startStream received on host")
        case .videoFrame:
            appendLog("Unexpected video frame received on host")
        case .mockFrame:
            appendLog("Unexpected mock frame received on host")
        case .stopStream:
            appendLog("Client stopped stream")
            extendedDisplayGuideWindowController.hide()
            connectedClientDevice = nil
            await sessionController.transition(
                to: .idle,
                connectionState: .idle,
                statusText: "Ready"
            )
        case let .heartbeat(date):
            appendLog("Heartbeat from client at \(date.formatted(date: .omitted, time: .standard))")
        case let .error(code, message):
            appendLog("Client error \(code.rawValue): \(message)")
            extendedDisplayGuideWindowController.hide()
            connectedClientDevice = nil
            await sessionController.transition(
                to: .failed,
                connectionState: .failed,
                statusText: message
            )
        case let .negotiate(configuration):
            appendLog("Client proposed configuration \(configuration.width)x\(configuration.height)")
        }

        state = await sessionController.snapshot()
    }

    private func appendLog(_ message: String) {
        eventLog.insert(EventLogEntry(message: message), at: 0)
        if eventLog.count > 20 {
            eventLog.removeLast(eventLog.count - 20)
        }
    }

    var connectedDeviceSummary: String {
        guard let connectedClientDevice else {
            return "No iPhone connected"
        }

        return "\(connectedClientDevice.name) • \(connectedClientDevice.model)"
    }

    var connectionLabel: String {
        switch state.connectionState {
        case .idle:
            "Idle"
        case .discovering:
            "Preparing"
        case .connected:
            "Connected"
        case .streaming:
            "Streaming"
        case .failed:
            "Failed"
        }
    }

    private func preferredConfiguration(for transportMode: TransportMode) -> DisplaySessionConfiguration {
        switch transportMode {
        case .wiredUSB:
            let resolution = selectedResolutionOption.dimensions
            return DisplaySessionConfiguration(
                width: resolution.width,
                height: resolution.height,
                targetFPS: selectedPerformanceProfile.targetFPS,
                codec: .h264,
                quality: selectedPerformanceProfile.qualityPreset
            )
        case .loopback, .network:
            return state.configuration
        }
    }

    private func startPreviewStream(over transport: any Transport) {
        mockStreamTask?.cancel()
        hasLoggedFirstPreviewFrame = false
        sentPreviewFrameCount = 0
        appendLog("Starting preview frame stream")

        mockStreamTask = Task {
            let configuration = await self.sessionController.snapshot().configuration
            let frameInterval = max(16, 1000 / max(1, min(configuration.targetFPS, 60)))

            while !Task.isCancelled {
                do {
                    let frame = try await self.captureCoordinator.capturePreviewFrame(
                        configuration: configuration,
                        displayID: self.activeCaptureDisplayID
                    )
                    if !self.hasLoggedFirstPreviewFrame {
                        self.hasLoggedFirstPreviewFrame = true
                        await MainActor.run {
                            self.appendLog("First preview frame encoded: \(frame.codec.rawValue) \(frame.width)x\(frame.height) payload \(frame.payload.count) bytes")
                        }
                    }
                    try await transport.send(.videoFrame(frame))
                    self.sentPreviewFrameCount += 1
                } catch {
                    let localizedDescription = error.localizedDescription
                    let isTransientCaptureFailure =
                        localizedDescription.localizedCaseInsensitiveContains("stopped by the system") ||
                        localizedDescription.localizedCaseInsensitiveContains("stream stopped") ||
                        localizedDescription.localizedCaseInsensitiveContains("pixel buffer") ||
                        localizedDescription.localizedCaseInsensitiveContains("capture stream is unavailable")

                    if isTransientCaptureFailure {
                        await MainActor.run {
                            self.appendLog("Capture interrupted by the system. Restarting preview stream")
                        }

                        do {
                            try await self.captureCoordinator.recoverCapture(
                                configuration: configuration,
                                displayID: self.activeCaptureDisplayID
                            )
                            try? await Task.sleep(for: .milliseconds(120))
                            continue
                        } catch {
                            await MainActor.run {
                                self.appendLog("Capture recovery failed: \(error.localizedDescription)")
                            }
                        }
                    }

                    await MainActor.run {
                        self.appendLog("Preview stream failed: \(localizedDescription)")
                        self.extendedDisplayGuideWindowController.hide()
                    }
                    await self.sessionController.transition(
                        to: .failed,
                        connectionState: .failed,
                        statusText: localizedDescription
                    )
                    await MainActor.run {
                        self.state = configuration.withFailedState(
                            role: .host,
                            statusText: localizedDescription
                        )
                    }
                    break
                }

                try? await Task.sleep(for: .milliseconds(frameInterval))
            }
        }
    }
}

private extension DisplaySessionConfiguration {
    func withFailedState(role: SessionRole, statusText: String) -> DisplaySessionState {
        DisplaySessionState(
            role: role,
            phase: .failed,
            connectionState: .failed,
            statusText: statusText,
            configuration: self
        )
    }
}

private extension EventLogEntry {
    var isImportantEvent: Bool {
        let normalized = message.lowercased()
        let ignoredPrefixes = [
            "sent ",
            "heartbeat ",
            "starting preview frame stream"
        ]

        if ignoredPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return false
        }

        let importantMarkers = [
            "preparing",
            "virtual display",
            "client hello",
            "accepted",
            "stream started",
            "stopped",
            "failed",
            "blocked",
            "ready",
            "configuration",
            "recovery"
        ]

        return importantMarkers.contains { normalized.contains($0) }
    }
}
