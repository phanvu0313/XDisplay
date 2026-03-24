import AppKit
import SwiftUI

@MainActor
final class ExtendedDisplayGuideWindowController {
    private var window: NSWindow?
    private var activeDisplayID: CGDirectDisplayID?

    func show(on displayID: CGDirectDisplayID, configuration: DisplaySessionConfiguration) {
        guard let screen = screen(for: displayID) else {
            AppLogger.video.error("Unable to locate NSScreen for virtual display \(displayID)")
            return
        }

        let window = window ?? makeWindow()
        let size = NSSize(width: min(screen.frame.width * 0.62, 460), height: 260)
        let origin = NSPoint(
            x: screen.frame.midX - (size.width / 2),
            y: screen.frame.midY - (size.height / 2)
        )

        if let hostingView = window.contentView as? NSHostingView<ExtendedDisplayGuideView> {
            hostingView.rootView = ExtendedDisplayGuideView(configuration: configuration)
        }

        window.setFrame(NSRect(origin: origin, size: size), display: true)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        activeDisplayID = displayID
        AppLogger.video.info("Placed virtual display guide window on display \(displayID)")
    }

    func hide() {
        window?.orderOut(nil)
        activeDisplayID = nil
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "XDisplay"
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: ExtendedDisplayGuideView(configuration: .init()))
        return window
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }

            return screenNumber.uint32Value == displayID
        }
    }
}

private struct ExtendedDisplayGuideView: View {
    let configuration: DisplaySessionConfiguration

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.982, green: 0.983, blue: 0.978),
                    Color(red: 0.965, green: 0.966, blue: 0.959)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 18) {
                Text("XDisplay Live")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)

                VStack(alignment: .leading, spacing: 10) {
                    GuideMetricRow(label: "Display", value: "Extended")
                    GuideMetricRow(label: "Link", value: "USB")
                    GuideMetricRow(label: "Resolution", value: "\(configuration.width) × \(configuration.height)")
                    GuideMetricRow(label: "Refresh", value: "\(configuration.targetFPS) FPS")
                    GuideMetricRow(label: "Codec", value: configuration.codec.rawValue.uppercased())
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct GuideMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
    }
}
