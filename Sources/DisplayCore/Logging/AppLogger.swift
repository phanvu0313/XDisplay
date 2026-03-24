import OSLog

public enum AppLogger {
    public static let host = Logger(subsystem: "com.xdisplay.host", category: "host")
    public static let client = Logger(subsystem: "com.xdisplay.client", category: "client")
    public static let session = Logger(subsystem: "com.xdisplay.core", category: "session")
    public static let transport = Logger(subsystem: "com.xdisplay.core", category: "transport")
    public static let video = Logger(subsystem: "com.xdisplay.core", category: "video")
}
