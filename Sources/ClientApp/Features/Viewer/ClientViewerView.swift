import SwiftUI

struct ClientViewerView: View {
    @State private var viewModel = ClientViewerViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            Color.white.ignoresSafeArea()

            ClientSetupView(
                displayScaleMode: $viewModel.displayScaleMode,
                state: viewModel.state,
                connectAction: connect
            )
        }
        .fullScreenCover(isPresented: displayPresentationBinding) {
            ClientImmersiveDisplayView(
                renderer: viewModel.displayRenderer,
                mockFrame: viewModel.latestFrame,
                statusText: viewModel.state.statusText,
                scaleMode: viewModel.displayScaleMode
            )
            .interactiveDismissDisabled()
        }
    }

    private func connect() {
        Task {
            await viewModel.connect()
        }
    }

    private var displayPresentationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isDisplayPresented },
            set: { _ in }
        )
    }
}
