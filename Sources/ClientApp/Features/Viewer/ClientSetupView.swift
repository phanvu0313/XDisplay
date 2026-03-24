import SwiftUI

struct ClientSetupView: View {
    @Binding var displayScaleMode: ClientDisplayScaleMode
    let state: DisplaySessionState
    let connectAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("XDisplay")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(.black)

                                Text("Connect by USB and start the display.")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(Color.black.opacity(0.55))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            sectionCard(title: "Connection") {
                                HStack(spacing: 14) {
                                    Image(systemName: "cable.connector")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("USB Cable")
                                            .font(.body.bold())
                                            .foregroundStyle(.black)
                                        Text("Wired only")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(Color.blue.opacity(0.1))
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
                                            .foregroundStyle(.black)
                                    }

                                    Text("\(state.configuration.width)×\(state.configuration.height) • \(state.configuration.targetFPS) FPS")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.black.opacity(0.5))
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
                                            colors: [Color.blue, Color.blue.opacity(0.82)],
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
                        .background(Color.white)
                    }
                }
            }
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.97))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private var statusColor: Color {
        switch state.connectionState {
        case .idle:
            .gray
        case .discovering:
            .orange
        case .connected:
            .blue
        case .streaming:
            .green
        case .failed:
            .red
        }
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
