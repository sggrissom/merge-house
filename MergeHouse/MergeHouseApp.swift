import SwiftUI
import UIKit

@main
struct MergeHouseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainMenuView()
        }
    }
}

/// The Info.plist orientation keys alone are not reliable on iPad — the system
/// ignores them for an app that supports multitasking. This is the runtime hook
/// it always asks, so the lock holds either way.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .landscape : .allButUpsideDown
    }
}
