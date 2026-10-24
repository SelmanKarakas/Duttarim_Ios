import UIKit
import Capacitor

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let paperColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 8.0 / 255.0, green: 12.0 / 255.0, blue: 18.0 / 255.0, alpha: 1.0)
            }
            return UIColor(red: 247.0 / 255.0, green: 248.0 / 255.0, blue: 246.0 / 255.0, alpha: 1.0)
        }
        if window == nil {
            let appWindow = UIWindow(windowScene: windowScene)
            appWindow.rootViewController = MyViewController()
            window = appWindow
        }

        window?.backgroundColor = paperColor
        window?.rootViewController?.view.backgroundColor = paperColor
        window?.makeKeyAndVisible()

        SceneDelegateProxy.shared.scene(scene, willConnectTo: session, options: connectionOptions)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        SceneDelegateProxy.shared.scene(scene, openURLContexts: URLContexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        SceneDelegateProxy.shared.scene(scene, continue: userActivity)
    }
}
