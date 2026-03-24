import CoreGraphics
import Foundation

@MainActor
final class ScreenCapturePermissionCoordinator {
    func authorizeIfNeeded() throws {
        guard !CGPreflightScreenCaptureAccess() else {
            return
        }

        let accessGranted = CGRequestScreenCaptureAccess()

        if accessGranted {
            throw ScreenCapturePermissionError.restartRequired
        }

        throw ScreenCapturePermissionError.denied
    }
}

enum ScreenCapturePermissionError: LocalizedError {
    case denied
    case restartRequired

    var errorDescription: String? {
        switch self {
        case .denied:
            "Screen Recording permission is required. Enable it for XDisplayHost in System Settings > Privacy & Security > Screen Recording."
        case .restartRequired:
            "Screen Recording was granted. Quit and reopen XDisplayHost, then press Start Display again."
        }
    }
}
