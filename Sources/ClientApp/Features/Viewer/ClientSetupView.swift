import SwiftUI

struct ClientSetupView: View {
    let state: DisplaySessionState
    let connectAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        XDisplayTheme.backgroundTop,
                        XDisplayTheme.backgroundBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                statusPill

                                Text("XDisplay")
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundStyle(XDisplayTheme.primaryText)

                                Text("Use your iPhone as a wired secondary display.")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(XDisplayTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            heroCard

                            sectionCard(title: "Connection") {
                                HStack(spacing: 14) {
                                    Image(systemName: "cable.connector")
                                        .font(.title3)
                                        .foregroundStyle(XDisplayTheme.accent)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("USB Cable")
                                            .font(.body.bold())
                                            .foregroundStyle(XDisplayTheme.primaryText)
                                        Text("Wired only • ready when the Mac starts")
                                            .font(.footnote)
                                            .foregroundStyle(XDisplayTheme.secondaryText)
                                    }

                                    Spacer()

                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(XDisplayTheme.accent)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(XDisplayTheme.accentSoft)
                                )
                            }

                            sectionCard(title: "Status") {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 10) {
                                        Circle()
                                            .fill(statusColor)
                                            .frame(width: 10, height: 10)

                                        Text(state.statusText)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(XDisplayTheme.primaryText)
                                    }

                                    Text("\(state.configuration.width)×\(state.configuration.height) • \(state.configuration.targetFPS) FPS")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(XDisplayTheme.secondaryText)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        .padding(.bottom, 32)
                        .frame(minHeight: max(proxy.size.height - 88, 0), alignment: .top)
                    }

                    VStack(spacing: 0) {
                        Divider()

                        Button(action: connectAction) {
                            HStack(spacing: 10) {
                                Image(systemName: "cable.connector")
                                Text(buttonTitle)
                            }
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(
                                        LinearGradient(
                                            colors: [XDisplayTheme.accent, XDisplayTheme.accent.opacity(0.82)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isConnectDisabled)
                        .opacity(isConnectDisabled ? 0.55 : 1)
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                        .background(Color.white.opacity(0.94))
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Setup")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(XDisplayTheme.secondaryText)

            HStack(spacing: 12) {
                featureBadge(title: "USB", subtitle: "Cable")
                featureBadge(title: "Ext", subtitle: "Display")
                featureBadge(title: "60+", subtitle: "FPS")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(XDisplayTheme.panel, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(XDisplayTheme.panelBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 18, x: 0, y: 10)
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(XDisplayTheme.primaryText)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(XDisplayTheme.panel)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(XDisplayTheme.panelBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.03), radius: 14, x: 0, y: 8)
    }

    private var statusColor: Color {
        switch state.connectionState {
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

    private var statusPill: some View {
        Label(connectionLabel, systemImage: "circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(statusColor.opacity(0.14), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var connectionLabel: String {
        switch state.connectionState {
        case .idle:
            "Ready"
        case .discovering:
            "Connecting"
        case .connected:
            "Connected"
        case .streaming:
            "Streaming"
        case .failed:
            "Error"
        }
    }

    private func featureBadge(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(XDisplayTheme.primaryText)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(XDisplayTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(XDisplayTheme.accentSoft, in: RoundedRectangle(cornerRadius: 18))
    }

    private var isConnectDisabled: Bool {
        switch state.connectionState {
        case .discovering, .streaming:
            true
        case .idle, .connected, .failed:
            false
        }
    }

    private var buttonTitle: String {
        switch state.connectionState {
        case .discovering:
            "Connecting Cable"
        case .streaming:
            "Streaming"
        case .idle, .connected, .failed:
            "Connect Cable"
        }
    }
}
