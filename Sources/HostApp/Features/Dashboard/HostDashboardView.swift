import SwiftUI

struct HostDashboardView: View {
    @State private var viewModel = HostDashboardViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("XDisplay Host")
                            .font(.system(size: 24, weight: .bold))
                        Text("USB Extended Display")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    statusPill
                }

                HStack(spacing: 12) {
                    compactCard(
                        title: "Device",
                        value: viewModel.connectedClientDevice?.name ?? "Waiting for iPhone",
                        detail: viewModel.connectedClientDevice?.model ?? "USB ready"
                    )

                    compactCard(
                        title: "Stream",
                        value: "\(viewModel.state.configuration.width)×\(viewModel.state.configuration.height)",
                        detail: "\(viewModel.state.configuration.targetFPS) FPS • \(viewModel.selectedPerformanceProfile.title)"
                    )
                }

                controlSection(
                    title: "Profile",
                    subtitle: viewModel.selectedProfileSummary
                ) {
                    Picker("Profile", selection: $viewModel.selectedPerformanceProfile) {
                        ForEach(HostPerformanceProfile.allCases) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isStreamingOrPreparing)
                }

                controlSection(
                    title: "Resolution",
                    subtitle: "iPhone ratio • \(viewModel.selectedResolutionSummary)"
                ) {
                    Picker("Resolution", selection: $viewModel.selectedResolutionOption) {
                        ForEach(HostResolutionOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isStreamingOrPreparing)
                }

                HStack(spacing: 10) {
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

                    Spacer()

                    Text(viewModel.state.statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                GroupBox {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.visibleEventLog.prefix(6)) { entry in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(entry.message)
                                        .font(.system(size: 12))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 78, maxHeight: 108)
                } label: {
                    Text("Activity")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(minWidth: 500, idealWidth: 520, maxWidth: 560, minHeight: 340)
        }
    }

    private var statusPill: some View {
        Label(viewModel.connectionLabel, systemImage: "circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(statusTint.opacity(0.14), in: Capsule())
            .foregroundStyle(statusTint)
    }

    private func compactCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }

    private func controlSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
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
