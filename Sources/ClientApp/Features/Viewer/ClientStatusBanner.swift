import SwiftUI

struct ClientStatusBanner: View {
    let state: DisplaySessionState
    let latestVideoFrame: EncodedVideoFrame?

    var body: some View {
        HStack(spacing: ClientViewerTheme.panelSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.statusText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("\(state.phase.rawValue) • \(state.connectionState.rawValue)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if let latestVideoFrame {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Frame \(latestVideoFrame.frameIndex)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(latestVideoFrame.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(ClientViewerTheme.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ClientViewerTheme.cardCornerRadius))
    }
}
