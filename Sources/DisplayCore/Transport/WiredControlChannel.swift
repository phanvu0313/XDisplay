import Foundation
import Network

final class WiredControlChannel: @unchecked Sendable {
    private enum Constants {
        static let packetHeaderLength = 5
        static let videoHeaderLength = 4
    }

    private struct PendingPacket {
        let data: Data
        let continuation: CheckedContinuation<Void, Error>
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue: DispatchQueue
    private var stream: AsyncStream<ControlEnvelope>
    private var continuation: AsyncStream<ControlEnvelope>.Continuation?
    private var connection: NWConnection?
    private var listener: NWListener?
    private var receiveBuffer = Data()
    private var pendingPackets: [PendingPacket] = []
    private var isFlushingPendingPackets = false

    init(label: String) {
        queue = DispatchQueue(label: label)
        stream = AsyncStream { _ in }
        resetStream()
    }

    func startClient(host: NWEndpoint.Host, port: NWEndpoint.Port) {
        resetStream()
        let connection = NWConnection(host: host, port: port, using: .tcp)
        adoptConnection(connection)
        connection.start(queue: queue)
    }

    func startServer(port: NWEndpoint.Port) throws {
        resetStream()
        let listener = try NWListener(using: .tcp, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.adoptConnection(connection)
            connection.start(queue: self?.queue ?? DispatchQueue.global(qos: .userInitiated))
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() {
        failPendingPackets(with: TransportError.connectionUnavailable)
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        receiveBuffer.removeAll(keepingCapacity: false)
        continuation?.finish()
    }

    func send(_ envelope: ControlEnvelope) async throws {
        let packet = try makePacket(for: envelope)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: TransportError.connectionUnavailable)
                    return
                }

                self.pendingPackets.append(
                    PendingPacket(data: packet, continuation: continuation)
                )
                self.flushPendingPacketsIfPossible()
            }
        }
    }

    func receiveStream() -> AsyncStream<ControlEnvelope> {
        stream
    }

    private func resetStream() {
        continuation = nil
        var localContinuation: AsyncStream<ControlEnvelope>.Continuation?
        stream = AsyncStream { streamContinuation in
            localContinuation = streamContinuation
        }
        continuation = localContinuation
    }

    private func adoptConnection(_ connection: NWConnection) {
        self.connection?.cancel()
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                self.flushPendingPacketsIfPossible()
                self.receiveNextChunk()
            case let .failed(error):
                AppLogger.transport.error("Wired control connection failed: \(error.localizedDescription, privacy: .public)")
                self.failPendingPackets(with: error)
                self.continuation?.finish()
            case .cancelled:
                self.failPendingPackets(with: TransportError.connectionUnavailable)
                self.continuation?.finish()
            default:
                break
            }
        }
    }

    private func flushPendingPacketsIfPossible() {
        guard !isFlushingPendingPackets else {
            return
        }

        guard let connection, !pendingPackets.isEmpty else {
            return
        }

        isFlushingPendingPackets = true
        let pending = pendingPackets.removeFirst()
        sendPacket(pending.data, over: connection) { [weak self] result in
            guard let self else {
                pending.continuation.resume(throwing: TransportError.connectionUnavailable)
                return
            }

            self.queue.async {
                self.isFlushingPendingPackets = false
                switch result {
                case .success:
                    pending.continuation.resume()
                    self.flushPendingPacketsIfPossible()
                case let .failure(error):
                    AppLogger.transport.error("Wired control send failed: \(error.localizedDescription, privacy: .public)")
                    pending.continuation.resume(throwing: error)
                    self.failPendingPackets(with: error)
                }
            }
        }
    }

    private func sendPacket(
        _ packet: Data,
        over connection: NWConnection,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        connection.send(content: packet, completion: .contentProcessed { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        })
    }

    private func failPendingPackets(with error: Error) {
        let queued = pendingPackets
        pendingPackets.removeAll()
        isFlushingPendingPackets = false
        for pending in queued {
            pending.continuation.resume(throwing: error)
        }
    }

    private func receiveNextChunk() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] content, _, isComplete, error in
            guard let self else { return }

            if let error {
                AppLogger.transport.error("Wired control receive failed: \(error.localizedDescription, privacy: .public)")
                self.continuation?.finish()
                return
            }

            if let content, !content.isEmpty {
                self.receiveBuffer.append(content)
                self.processBufferedMessages()
            }

            if isComplete {
                self.continuation?.finish()
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
                AppLogger.transport.error("Failed decoding wired packet: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func makePacket(for envelope: ControlEnvelope) throws -> Data {
        switch envelope.message {
        case let .videoFrame(frame):
            let metadata = VideoFramePacketMetadata(envelope: envelope, frame: frame)
            let metadataPayload = try encoder.encode(metadata)

            var body = Data()
            body.appendUInt32(UInt32(metadataPayload.count))
            body.append(metadataPayload)
            body.append(frame.payload)

            return Data.packet(kind: .videoFrame, body: body)
        default:
            let payload = try encoder.encode(envelope)
            return Data.packet(kind: .control, body: payload)
        }
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
