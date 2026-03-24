import Foundation

enum NetworkPacketKind: UInt8, Sendable {
    case control = 1
    case videoFrame = 2
}

struct VideoFramePacketMetadata: Codable, Sendable {
    let envelopeID: UUID
    let sessionID: UUID
    let protocolVersion: Int
    let senderRole: SessionRole
    let sentAt: Date
    let frameID: UUID
    let frameIndex: Int
    let frameTimestamp: Date
    let width: Int
    let height: Int
    let codec: VideoCodec

    init(envelope: ControlEnvelope, frame: EncodedVideoFrame) {
        envelopeID = envelope.id
        sessionID = envelope.sessionID
        protocolVersion = envelope.protocolVersion
        senderRole = envelope.senderRole
        sentAt = envelope.sentAt
        frameID = frame.id
        frameIndex = frame.frameIndex
        frameTimestamp = frame.timestamp
        width = frame.width
        height = frame.height
        codec = frame.codec
    }

    func makeEnvelope(payload: Data) -> ControlEnvelope {
        ControlEnvelope(
            id: envelopeID,
            sessionID: sessionID,
            protocolVersion: protocolVersion,
            senderRole: senderRole,
            sentAt: sentAt,
            message: .videoFrame(
                EncodedVideoFrame(
                    id: frameID,
                    frameIndex: frameIndex,
                    timestamp: frameTimestamp,
                    width: width,
                    height: height,
                    codec: codec,
                    payload: payload
                )
            )
        )
    }
}
