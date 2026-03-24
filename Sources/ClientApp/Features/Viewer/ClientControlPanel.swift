import SwiftUI

struct ClientControlPanel: View {
    @Binding var selectedTransportMode: TransportMode
    let state: DisplaySessionState
    let eventLog: [EventLogEntry]
    @Binding var showsDiagnostics: Bool
    let connectAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ClientViewerTheme.panelSpacing) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: ClientViewerTheme.panelSpacing) {
                    transportPicker
                    connectButton
                }

                VStack(alignment: .leading, spacing: ClientViewerTheme.panelSpacing) {
                    transportPicker
                    connectButton
                }
            }

            DisclosureGroup(isExpanded: $showsDiagnostics) {
                VStack(alignment: .leading, spacing: ClientViewerTheme.panelSpacing) {
                    sessionSummary

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(eventLog) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.message)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(minHeight: 90, maxHeight: 160)
                }
                .padding(.top, 6)
            } label: {
                Label("Diagnostics", systemImage: showsDiagnostics ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                    .font(.headline)
            }
            .tint(.primary)
        }
        .padding(ClientViewerTheme.cardPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ClientViewerTheme.cardCornerRadius))
    }

    private var transportPicker: some View {
        Picker("Transport", selection: $selectedTransportMode) {
            Text("Wired USB").tag(TransportMode.wiredUSB)
            Text("Loopback").tag(TransportMode.loopback)
            Text("Network").tag(TransportMode.network)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Transport")
    }

    private var connectButton: some View {
        Button(buttonTitle, systemImage: buttonSystemImage, action: connectAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(minHeight: 44)
            .disabled(isConnectDisabled)
    }

    private var sessionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Phase", value: state.phase.rawValue)
            LabeledContent("State", value: state.connectionState.rawValue)
            LabeledContent(
                "Target",
                value: "\(state.configuration.width)x\(state.configuration.height) @ \(state.configuration.targetFPS) FPS"
            )
        }
        .font(.subheadline)
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
            "Connecting"
        case .streaming:
            "Connected"
        case .idle, .connected, .failed:
            "Connect"
        }
    }

    private var buttonSystemImage: String {
        switch state.connectionState {
        case .discovering:
            "dot.radiowaves.left.and.right"
        case .streaming:
            "display"
        case .idle, .connected, .failed:
            "bolt.horizontal.circle.fill"
        }
    }
}
