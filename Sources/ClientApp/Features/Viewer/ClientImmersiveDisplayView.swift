import SwiftUI
import UIKit

struct ClientImmersiveDisplayView: View {
    let renderer: RemoteDisplayRenderer
    let mockFrame: MockFrameDescriptor?
    let statusText: String
    let scaleMode: ClientDisplayScaleMode

    var body: some View {
        ClientDisplaySurfaceView(
            renderer: renderer,
            mockFrame: mockFrame,
            statusText: statusText,
            scaleMode: scaleMode
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
