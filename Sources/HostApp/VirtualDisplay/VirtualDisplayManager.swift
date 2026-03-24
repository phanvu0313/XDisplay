import Foundation

@MainActor
final class VirtualDisplayManager {
    private let provider: any VirtualDisplayProvider

    init(provider: any VirtualDisplayProvider = ExperimentalVirtualDisplayProvider()) {
        self.provider = provider
    }

    func prepareVirtualDisplay(configuration: DisplaySessionConfiguration) async throws -> UInt32 {
        try await provider.prepare(configuration: configuration)
    }
}
