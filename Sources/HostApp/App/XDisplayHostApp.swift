import SwiftUI

@main
struct XDisplayHostApp: App {
    @NSApplicationDelegateAdaptor(HostAppDelegate.self) private var appDelegate
    @State private var viewModel = HostDashboardViewModel()

    var body: some Scene {
        Window("XDisplay Host", id: "host-dashboard") {
            HostDashboardView(viewModel: viewModel)
        }
        .defaultSize(width: 444, height: 640)
        .windowResizability(.contentSize)

        MenuBarExtra("XDisplay", systemImage: "display.2") {
            HostMenuBarView(viewModel: viewModel)
        }
    }
}
