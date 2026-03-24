import Foundation

public struct SessionRuntime {
    public static let protocolVersion = 1

    public static func makeDefaultSessionID() -> UUID {
        UUID(uuidString: "2C1D0D49-7F3A-4D4B-AF17-5AEE5F568001") ?? UUID()
    }
}
