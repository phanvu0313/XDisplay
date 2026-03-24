import Foundation
import Network

public final class NetworkTransport: @unchecked Sendable, Transport {
    public let mode: TransportMode = .network

    private enum Constants {
        static let bonjourType = "_xdisplay._tcp"
        static let bonjourDomain = "local."
        static let port: UInt16 = 38491
        static let packetHeaderLength = 5
        static let videoHeaderLength = 4
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.xdisplay.network-transport")

    private var role: SessionRole?
    private var sessionID: UUID?
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private var pendingMessages: [ControlMessage] = []

    private let stream: AsyncStream<ControlEnvelope>
    private var continuation: AsyncStream<ControlEnvelope>.Continuation?

    public init() {
        var continuation: AsyncStream<ControlEnvelope>.Continuation?
        stream = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation
    }

    public func start(sessionID: UUID, role: SessionRole) async throws {
        self.sessionID = sessionID
        self.role = role

        switch role {
        case .host:
            try startListener(sessionID: sessionID)
        case .client:
            startBrowser()
        }

        AppLogger.transport.info("Network transport started for \(role.rawValue, privacy: .public)")
    }

    public func stop() async {
        browser?.cancel()
        browser = nil

        listener?.cancel()
        listener = nil

        connection?.cancel()
        connection = nil

        pendingMessages.removeAll()
        receiveBuffer.removeAll(keepingCapacity: false)

        AppLogger.transport.info("Network transport stopped")
    }

    public func send(_ message: ControlMessage) async throws {
        guard sessionID != nil, role != nil else {
            throw TransportError.notStarted
        }

        if connection == nil {
            pendingMessages.append(message)
            AppLogger.transport.debug("Queued network message before connection became ready")
            return
        }

        try sendImmediately(message)
    }

    public func receiveStream() -> AsyncStream<ControlEnvelope> {
        stream
    }

    private func startListener(sessionID: UUID) throws {
        let parameters = NWParameters.tcp
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: Constants.port))
        let serviceName = "xdisplay-\(sessionID.uuidString.prefix(8))"

        listener.service = NWListener.Service(name: serviceName, type: Constants.bonjourType)
        listener.stateUpdateHandler = { state in
            AppLogger.transport.debug("Listener state: \(String(describing: state), privacy: .public)")
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.adoptConnection(connection)
        }

        self.listener = listener
        listener.start(queue: queue)
    }

    private func startBrowser() {
        let parameters = NWParameters.tcp
        let browser = NWBrowser(
            for: .bonjour(type: Constants.bonjourType, domain: Constants.bonjourDomain),
            using: parameters
        )

        browser.stateUpdateHandler = { state in
            AppLogger.transport.debug("Browser state: \(String(describing: state), privacy: .public)")
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, self.connection == nil, let endpoint = results.first?.endpoint else {
                return
            }
            self.connect(to: endpoint)
        }

        self.browser = browser
        browser.start(queue: queue)
    }

    private func connect(to endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        adoptConnection(connection)
        browser?.cancel()
        browser = nil
    }

    private func adoptConnection(_ connection: NWConnection) {
        self.connection?.cancel()
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                AppLogger.transport.info("Network connection ready")
                self.flushPendingMessages()
                self.receiveNextChunk()
            case let .failed(error):
                AppLogger.transport.error("Network connection failed: \(error.localizedDescription, privacy: .public)")
            case .cancelled:
                AppLogger.transport.info("Network connection cancelled")
            default:
                AppLogger.transport.debug("Connection state: \(String(describing: state), privacy: .public)")
            }
        }

        connection.start(queue: queue)
    }

    private func flushPendingMessages() {
        let queued = pendingMessages
        pendingMessages.removeAll()

        for message in queued {
            do {
                try sendImmediately(message)
            } catch {
                AppLogger.transport.error("Failed flushing pending message: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func sendImmediately(_ message: ControlMessage) throws {
        guard let sessionID, let role, let connection else {
            throw TransportError.notStarted
        }

        let envelope = ControlEnvelope(
            sessionID: sessionID,
            senderRole: role,
            message: message
        )

        let packet = try makePacket(for: envelope)

        connection.send(content: packet, completion: .contentProcessed { error in
            if let error {
                AppLogger.transport.error("Network send failed: \(error.localizedDescription, privacy: .public)")
            }
        })
    }

    private func receiveNextChunk() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] content, _, isComplete, error in
            guard let self else { return }

            if let error {
                AppLogger.transport.error("Network receive failed: \(error.localizedDescription, privacy: .public)")
                return
            }

            if let content, !content.isEmpty {
                self.receiveBuffer.append(content)
                self.processBufferedMessages()
            }

            if isComplete {
                AppLogger.transport.info("Network receive completed")
                return
            }

            self.receiveNextChunk()
        }
    }

    private func processBufferedMessages() {
        while receiveBuffer.count >= Constants.packetHeaderLength {
            guard
                let kindRaw = receiveBuffer.first,
                let kind = NetworkPacketKind(rawValue: kindRaw)
            else {
                AppLogger.transport.error("Unknown network packet kind")
                receiveBuffer.removeAll(keepingCapacity: false)
                return
            }

            let bodyLength = receiveBuffer.readUInt32(at: 1)
            let totalLength = Constants.packetHeaderLength + Int(bodyLength)

            guard receiveBuffer.count >= totalLength else {
                return
            }

            let body = receiveBuffer.subdata(in: Constants.packetHeaderLength..<totalLength)
            receiveBuffer.removeSubrange(0..<totalLength)

            do {
                let envelope = try decodePacket(kind: kind, body: body)
                continuation?.yield(envelope)
            } catch {
                AppLogger.transport.error("Failed to decode packet: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func makePacket(for envelope: ControlEnvelope) throws -> Data {
        switch envelope.message {
        case let .videoFrame(frame):
            return try makeVideoFramePacket(envelope: envelope, frame: frame)
        default:
            let payload = try encoder.encode(envelope)
            return Data.packet(kind: .control, body: payload)
        }
    }

    private func makeVideoFramePacket(envelope: ControlEnvelope, frame: EncodedVideoFrame) throws -> Data {
        let metadata = VideoFramePacketMetadata(envelope: envelope, frame: frame)
        let metadataPayload = try encoder.encode(metadata)

        var body = Data()
        body.appendUInt32(UInt32(metadataPayload.count))
        body.append(metadataPayload)
        body.append(frame.payload)

        return Data.packet(kind: .videoFrame, body: body)
    }

    private func decodePacket(kind: NetworkPacketKind, body: Data) throws -> ControlEnvelope {
        switch kind {
        case .control:
            return try decoder.decode(ControlEnvelope.self, from: body)
        case .videoFrame:
            guard body.count >= Constants.videoHeaderLength else {
                throw TransportError.receiveFailed
            }

            let metadataLength = Int(body.readUInt32(at: 0))
            let metadataStart = Constants.videoHeaderLength
            let metadataEnd = metadataStart + metadataLength

            guard body.count >= metadataEnd else {
                throw TransportError.receiveFailed
            }

            let metadataPayload = body.subdata(in: metadataStart..<metadataEnd)
            let payload = body.subdata(in: metadataEnd..<body.count)
            let metadata = try decoder.decode(VideoFramePacketMetadata.self, from: metadataPayload)
            return metadata.makeEnvelope(payload: payload)
        }
    }
}

private extension Data {
    static func packet(kind: NetworkPacketKind, body: Data) -> Data {
        var packet = Data([kind.rawValue])
        packet.appendUInt32(UInt32(body.count))
        packet.append(body)
        return packet
    }

    mutating func appendUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { bytes in
            append(contentsOf: bytes)
        }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        let range = offset..<(offset + 4)
        return subdata(in: range).withUnsafeBytes { rawBuffer in
            rawBuffer.load(as: UInt32.self).bigEndian
        }
    }
}
