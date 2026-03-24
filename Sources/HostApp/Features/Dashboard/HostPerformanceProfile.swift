import Foundation

enum HostPerformanceProfile: String, CaseIterable, Identifiable {
    case smooth
    case balanced
    case sharp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smooth:
            "Smooth"
        case .balanced:
            "Balanced"
        case .sharp:
            "Sharp"
        }
    }

    var summary: String {
        switch self {
        case .smooth:
            "60 FPS, lower latency, softer detail"
        case .balanced:
            "60 FPS, cleaner image, balanced load"
        case .sharp:
            "60 FPS, highest detail, heavier encode"
        }
    }

    var qualityPreset: StreamQualityPreset {
        switch self {
        case .smooth:
            .lowLatency
        case .balanced:
            .balanced
        case .sharp:
            .sharp
        }
    }

    var targetFPS: Int {
        60
    }
}
