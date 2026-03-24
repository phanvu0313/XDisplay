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
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 260),
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
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 1.0)
            let hue = t.truncatingRemainder(dividingBy: 12.0) / 12.0

            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.22, brightness: 1.0),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("XDisplay Live")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.black)

                        Spacer()

                        Text(context.date.formatted(date: .omitted, time: .standard))
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.72))
                    }

                    Text("This window is rendered on the virtual extended display. The moving bar and clock should animate on iPhone if the stream is live.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.72))

                    GeometryReader { proxy in
                        let width = max(proxy.size.width - 88, 1)
                        let x = 24 + width * phase

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.08))
                                .frame(height: 72)

                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hue: hue, saturation: 0.72, brightness: 0.96),
                                            Color.black.opacity(0.85)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 64, height: 56)
                                .offset(x: x)
                        }
                    }
                    .frame(height: 72)

                    HStack(spacing: 16) {
                        GuideBadge(label: "Extended", systemImage: "display.2")
                        GuideBadge(label: "Cable", systemImage: "cable.connector")
                        GuideBadge(label: "Live", systemImage: "waveform.path.ecg")
                    }

                    Spacer(minLength: 0)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

private struct GuideBadge: View {
    let label: String
    let systemImage: String

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.88), in: Capsule())
            .foregroundStyle(.black.opacity(0.82))
    }
}
