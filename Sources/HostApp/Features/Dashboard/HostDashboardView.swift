import SwiftUI

struct HostDashboardView: View {
    @State private var viewModel = HostDashboardViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("XDisplay Host")
                        .font(.system(size: 28, weight: .bold))
                    Text("USB Extended Display")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusPill
            }

            HStack(spacing: 16) {
                infoCard(
                    title: "Status",
                    value: viewModel.state.statusText,
                    detail: "\(viewModel.state.configuration.width)×\(viewModel.state.configuration.height) • \(viewModel.state.configuration.targetFPS) FPS"
                )

                infoCard(
                    title: "Device",
                    value: viewModel.connectedDeviceSummary,
                    detail: viewModel.lastConnectedAt.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? "Waiting for iPhone"
                )
            }

            HStack(spacing: 12) {
                Button("Start") {
                    Task { await viewModel.startSession() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isStreamingOrPreparing)

                Button("Stop") {
                    Task { await viewModel.stopSession() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!viewModel.isStreamingOrPreparing)
            }

            GroupBox("Recent Log") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.eventLog) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(entry.message)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 220)
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 380)
    }

    private var statusPill: some View {
        Label(viewModel.connectionLabel, systemImage: "circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(statusTint.opacity(0.14), in: Capsule())
            .foregroundStyle(statusTint)
    }

    private func infoCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }

    private var statusTint: Color {
        switch viewModel.state.connectionState {
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
}
