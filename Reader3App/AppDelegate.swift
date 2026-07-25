import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        let nav = UINavigationController(rootViewController: SetupViewController())
        nav.navigationBar.tintColor = UIColor(red: 145/255, green: 145/255, blue: 145/255, alpha: 1)
        window?.rootViewController = nav
        return true
    }
}
