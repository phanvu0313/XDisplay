import SwiftUI

struct HostMenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    let viewModel: HostDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("XDisplay")
                .font(.system(size: 13, weight: .bold))

            Text(viewModel.connectionLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(menuStatusTint)

            Divider()

            Button("Open Window") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "host-dashboard")
            }

            Button(viewModel.isStreamingOrPreparing ? "Stop Stream" : "Start Stream") {
                Task {
                    if viewModel.isStreamingOrPreparing {
                        await viewModel.stopSession()
                    } else {
                        await viewModel.startSession()
                    }
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 180)
    }

    private var menuStatusTint: Color {
        switch viewModel.state.connectionState {
        case .idle:
            XDisplayTheme.idle
        case .discovering:
            XDisplayTheme.warning
        case .connected:
            XDisplayTheme.accent
        case .streaming:
            XDisplayTheme.success
        case .failed:
            XDisplayTheme.danger
        }
    }
}

