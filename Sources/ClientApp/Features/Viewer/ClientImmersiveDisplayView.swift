import SwiftUI
import UIKit

struct ClientImmersiveDisplayView: View {
    let renderer: RemoteDisplayRenderer
    let mockFrame: MockFrameDescriptor?

    var body: some View {
        ClientDisplaySurfaceView(
            renderer: renderer,
            mockFrame: mockFrame
        )
        .ignoresSafeArea()
        .statusBarHidden()
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            ClientOrientationManager.activateDisplayOrientation()
        }
        .onDisappear {
            ClientOrientationManager.deactivateDisplayOrientation()
        }
    }
}
