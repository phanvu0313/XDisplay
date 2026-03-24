import Foundation

enum VirtualDisplayError: LocalizedError, Equatable {
    case unavailable
    case experimentalProviderRequired
    case creationFailed(String)
    case captureDisplayUnavailable(UInt32)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Virtual display provider is not implemented yet."
        case .experimentalProviderRequired:
            "A real Duet-style build requires an experimental virtual display provider, which is not wired up yet."
        case let .creationFailed(message):
            message
        case let .captureDisplayUnavailable(displayID):
            "The virtual display \(displayID) is not visible to ScreenCaptureKit yet."
        }
    }
}

protocol VirtualDisplayProvider: Sendable {
    func prepare(configuration: DisplaySessionConfiguration) async throws -> UInt32
}

struct UnimplementedVirtualDisplayProvider: VirtualDisplayProvider {
    func prepare(configuration _: DisplaySessionConfiguration) async throws -> UInt32 {
        throw VirtualDisplayError.experimentalProviderRequired
    }
}

@MainActor
final class ExperimentalVirtualDisplayProvider: VirtualDisplayProvider {
    private var session: XDVVirtualDisplaySession?

    func prepare(configuration: DisplaySessionConfiguration) async throws -> UInt32 {
        if let session {
            return session.displayID
        }

        let candidates: [(width: UInt32, height: UInt32, refreshRate: Double)] = [
            (UInt32(max(configuration.width, 1280)), UInt32(max(configuration.height, 720)), max(Double(configuration.targetFPS), 60)),
            (1920, 1080, 60),
            (1280, 720, 60)
        ]

        var failures: [String] = []

        for candidate in candidates {
            var error: NSError?
            let session = XDVVirtualDisplaySession(
                name: "XDisplay",
                width: candidate.width,
                height: candidate.height,
                refreshRate: candidate.refreshRate,
                error: &error
            )

            if error == nil {
                self.session = session
                return session.displayID
            }

            let message = error?.localizedDescription ?? "Unknown virtual display creation failure"
            failures.append("\(candidate.width)x\(candidate.height) @ \(Int(candidate.refreshRate))Hz: \(message)")
        }

        throw VirtualDisplayError.creationFailed(
            "CGVirtualDisplay creation failed. Tried \(failures.joined(separator: " | "))"
        )
    }
}
