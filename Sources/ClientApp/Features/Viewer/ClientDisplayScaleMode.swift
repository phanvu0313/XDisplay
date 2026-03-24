import Foundation

enum ClientDisplayScaleMode: String, CaseIterable, Identifiable {
    case smart
    case fit
    case fill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart:
            "Smart"
        case .fit:
            "Fit"
        case .fill:
            "Fill"
        }
    }
}
