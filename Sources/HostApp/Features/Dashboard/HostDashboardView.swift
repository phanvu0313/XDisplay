import SwiftUI

struct HostDashboardView: View {
    @State private var viewModel = HostDashboardViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("XDisplay Host")
                    .font(.system(size: 28, weight: .bold))
                Text(viewModel.state.statusText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.state.configuration.width)×\(viewModel.state.configuration.height) • \(viewModel.state.configuration.targetFPS) FPS • USB")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Start") {
                    Task { await viewModel.startSession() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isStreamingOrPreparing)

                Button("Stop") {
                    Task { await viewModel.stopSession() }
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isStreamingOrPreparing)
            }

            GroupBox("Log") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.eventLog) { entry in
                            Text(entry.message)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 180)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 340)
    }
}
