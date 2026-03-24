import Foundation

enum HostResolutionOption: String, CaseIterable, Identifiable {
    case medium
    case high
    case native

    var id: String { rawValue }

    var title: String {
        switch self {
        case .medium:
            "Medium"
        case .high:
            "High"
        case .native:
            "Native"
        }
    }

    var summary: String {
        switch self {
        case .medium:
            "844×390"
        case .high:
            "1688×780"
        case .native:
            "2532×1170"
        }
    }

    var dimensions: (width: Int, height: Int) {
        switch self {
        case .medium:
            (844, 390)
        case .high:
            (1688, 780)
        case .native:
            (2532, 1170)
        }
    }
}
