import SwiftUI

struct HostDashboardView: View {
    @Bindable var viewModel: HostDashboardViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [XDisplayTheme.backgroundTop, XDisplayTheme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                topSection
                primaryStatusSection
                configSection
                controlsSection
                activitySection
            }
            .padding(16)
            .frame(minWidth: 430, idealWidth: 444, maxWidth: 444, minHeight: 548)
        }
    }

    private var topSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("XDisplay Host")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(XDisplayTheme.primaryText)

                        Text("Wired extended display for iPhone")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(XDisplayTheme.secondaryText)
                    }

                    Spacer(minLength: 12)

                    statusPill
                }
            }
        }
    }

    private var primaryStatusSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                compactRow("Device", viewModel.connectedClientDevice?.name ?? "Waiting for iPhone")
                compactRow("Status", viewModel.connectionLabel)
                compactRow("Display", "\(viewModel.state.configuration.width) × \(viewModel.state.configuration.height)")
                compactRow("Stream", "\(viewModel.state.configuration.targetFPS) FPS")
            }
        }
    }

    private var configSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 14) {
                configBlock(
                    title: "Performance",
                    note: viewModel.selectedProfileSummary
                ) {
                    chipRow(HostPerformanceProfile.allCases, selection: viewModel.selectedPerformanceProfile) { profile in
                        viewModel.selectedPerformanceProfile = profile
                    }
                }

                configBlock(
                    title: "Resolution",
                    note: viewModel.selectedResolutionSummary
                ) {
                    chipRow(HostResolutionOption.allCases, selection: viewModel.selectedResolutionOption) { option in
                        viewModel.selectedResolutionOption = option
                    }
                }
            }
        }
    }

    private var controlsSection: some View {
        sectionCard {
            HStack(spacing: 10) {
                primaryButton(
                    title: "Start",
                    tint: XDisplayTheme.accent,
                    isDisabled: viewModel.isStreamingOrPreparing
                ) {
                    Task { await viewModel.startSession() }
                }

                primaryButton(
                    title: "Stop",
                    tint: .black,
                    isDisabled: !viewModel.isStreamingOrPreparing
                ) {
                    Task { await viewModel.stopSession() }
                }
            }
        }
    }

    private var activitySection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Activity")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(XDisplayTheme.primaryText)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        ForEach(viewModel.visibleEventLog.prefix(5)) { entry in
                            HStack(alignment: .top, spacing: 10) {
                                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(XDisplayTheme.secondaryText)

                                Text(entry.message)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(XDisplayTheme.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 110)
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusTint)
                .frame(width: 8, height: 8)

            Text(viewModel.connectionLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusTint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(statusTint.opacity(0.12), in: Capsule())
    }

    private func compactRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(XDisplayTheme.secondaryText)

            Spacer(minLength: 16)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(XDisplayTheme.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private func configBlock<Content: View>(title: String, note: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(XDisplayTheme.primaryText)

            content()

            Text(note)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(XDisplayTheme.secondaryText)
        }
    }

    private func chipRow<Option: Identifiable & Equatable & Hashable>(
        _ options: [Option],
        selection: Option,
        action: @escaping (Option) -> Void
    ) -> some View where Option: HostOptionTitleProviding {
        HStack(spacing: 8) {
            ForEach(options) { option in
                Button {
                    action(option)
                } label: {
                    Text(option.optionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == option ? Color.white : XDisplayTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(selection == option ? XDisplayTheme.accent : XDisplayTheme.panelAlt)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(selection == option ? XDisplayTheme.accent : XDisplayTheme.panelBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isStreamingOrPreparing)
                .opacity(viewModel.isStreamingOrPreparing ? 0.55 : 1)
            }
        }
    }

    private func primaryButton(title: String, tint: Color, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tint)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(XDisplayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(XDisplayTheme.panelBorder, lineWidth: 1)
        )
    }

    private var statusTint: Color {
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

private protocol HostOptionTitleProviding {
    var optionTitle: String { get }
}

extension HostPerformanceProfile: HostOptionTitleProviding {
    var optionTitle: String { title }
}

extension HostResolutionOption: HostOptionTitleProviding {
    var optionTitle: String { title }
}
