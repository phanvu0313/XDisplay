import SwiftUI
import UIKit

final class ClientRootHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        ClientAppDelegate.orientationLock
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        ClientAppDelegate.preferredOrientation
    }
}
