import SwiftUI
import UIKit

final class ClientSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let rootView = ClientViewerView()
        let controller = ClientRootHostingController(rootView: rootView)

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .white
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window

        _ = session
        _ = connectionOptions
    }
}
