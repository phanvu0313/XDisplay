import Foundation
import Network

public struct WiredTransportBridgeFactory {
    public init() {}

    public func makeBridge() -> any WiredTransportBridge {
        #if os(macOS)
        IProxyWiredTransportBridge()
        #elseif os(iOS)
        IOSAppWiredTransportBridge()
        #else
        UnimplementedWiredTransportBridge()
        #endif
    }
}

public struct IOSAppWiredTransportBridge: WiredTransportBridge {
    private enum Constants {
        static let devicePort: UInt16 = 38492
    }

    private let channel = WiredControlChannel(label: "com.xdisplay.wired-ios")

    public init() {}

    public func start(sessionID _: UUID, role _: SessionRole) async throws {
        do {
            channel.stop()
            try channel.startServer(port: NWEndpoint.Port(rawValue: Constants.devicePort)!)
        } catch {
            throw WiredTransportBridgeError.tunnelUnavailable(
                "Failed to start the iPhone cable listener on device port \(Constants.devicePort): \(error.localizedDescription)"
            )
        }
    }

    public func stop() async {
        channel.stop()
    }

    public func sendControl(_ envelope: ControlEnvelope) async throws {
        try await channel.send(envelope)
    }

    public func receiveControlStream() -> AsyncStream<ControlEnvelope> {
        channel.receiveStream()
    }
}

#if os(macOS)
public struct IProxyWiredTransportBridge: WiredTransportBridge {
    private enum Constants {
        static let devicePort: UInt16 = 38492
        static let iProxyPath = "/opt/homebrew/bin/iproxy"
        static let iDeviceIDPath = "/opt/homebrew/bin/idevice_id"
    }

    private final class State: @unchecked Sendable {
        let channel = WiredControlChannel(label: "com.xdisplay.wired-macos")
        var proxyProcess: Process?
        var localPort: UInt16?
    }

    private let state = State()

    public init() {}

    public func start(sessionID _: UUID, role _: SessionRole) async throws {
        await stop()
        let udid = try firstAttachedUDID()
        let localPort = try reserveAvailableLocalPort()
        try startIProxy(for: udid, localPort: localPort)
        state.localPort = localPort
        state.channel.startClient(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(rawValue: localPort)!
        )
    }

    public func stop() async {
        state.channel.stop()
        if let proxyProcess = state.proxyProcess, proxyProcess.isRunning {
            proxyProcess.terminate()
        }
        state.proxyProcess = nil
        state.localPort = nil
    }

    public func sendControl(_ envelope: ControlEnvelope) async throws {
        try await state.channel.send(envelope)
    }

    public func receiveControlStream() -> AsyncStream<ControlEnvelope> {
        state.channel.receiveStream()
    }

    private func firstAttachedUDID() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Constants.iDeviceIDPath)
        process.arguments = ["-l"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw WiredTransportBridgeError.probeFailed(
                "Unable to launch idevice_id: \(error.localizedDescription)"
            )
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown idevice_id failure"
            throw WiredTransportBridgeError.probeFailed("idevice_id failed: \(stderr)")
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard let udid = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { !$0.isEmpty })
        else {
            throw WiredTransportBridgeError.notAttached
        }

        return udid
    }

    private func startIProxy(for udid: String, localPort: UInt16) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Constants.iProxyPath)
        process.arguments = [
            "--udid", udid,
            "\(localPort):\(Constants.devicePort)"
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
        } catch {
            throw WiredTransportBridgeError.tunnelUnavailable(
                "Failed to launch iproxy: \(error.localizedDescription)"
            )
        }

        state.proxyProcess = process
        Thread.sleep(forTimeInterval: 0.4)

        if !process.isRunning, process.terminationStatus != 0 {
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown iproxy failure"
            throw WiredTransportBridgeError.tunnelUnavailable(
                "iproxy exited before the cable tunnel was ready: \(output)"
            )
        }
    }

    private func reserveAvailableLocalPort() throws -> UInt16 {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw WiredTransportBridgeError.tunnelUnavailable("Unable to allocate a local TCP socket for iproxy.")
        }

        defer {
            close(socketDescriptor)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(socketDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            throw WiredTransportBridgeError.tunnelUnavailable("Unable to bind a local TCP socket for iproxy.")
        }

        var assignedAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)

        let nameResult = withUnsafeMutablePointer(to: &assignedAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(socketDescriptor, sockaddrPointer, &length)
            }
        }

        guard nameResult == 0 else {
            throw WiredTransportBridgeError.tunnelUnavailable("Unable to resolve the assigned localhost port for iproxy.")
        }

        return UInt16(bigEndian: assignedAddress.sin_port)
    }
}
#endif
