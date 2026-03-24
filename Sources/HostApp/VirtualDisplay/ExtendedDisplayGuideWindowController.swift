import AppKit
import SwiftUI

@MainActor
final class ExtendedDisplayGuideWindowController {
    private var window: NSWindow?
    private var activeDisplayID: CGDirectDisplayID?

    func show(on displayID: CGDirectDisplayID) {
        guard let screen = screen(for: displayID) else {
            AppLogger.video.error("Unable to locate NSScreen for virtual display \(displayID)")
            return
        }

        let window = window ?? makeWindow()
        let size = NSSize(width: min(screen.frame.width * 0.72, 620), height: 260)
        let origin = NSPoint(
            x: screen.frame.midX - (size.width / 2),
            y: screen.frame.midY - (size.height / 2)
        )

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
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "XDisplay"
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: ExtendedDisplayGuideView())
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
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 20) {
                Text("XDisplay Live")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.black)

                HStack(spacing: 14) {
                    GuideInfoBox(title: "Display", value: "Extended", systemImage: "display.2")
                    GuideInfoBox(title: "Link", value: "USB", systemImage: "cable.connector")
                    GuideInfoBox(title: "Stream", value: "H.264", systemImage: "video")
                    GuideInfoBox(title: "Status", value: "Ready", systemImage: "checkmark.circle")
                }

                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct GuideInfoBox: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
    }
}
