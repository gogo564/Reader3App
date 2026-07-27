import UIKit

func crashLog(_ msg: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let log = "[\(formatter.string(from: Date()))] \(msg)\n"
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let url = dir.appendingPathComponent("crash.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(log.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? log.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

func exceptionHandler(_ exception: NSException) {
    crashLog("NSException: \(exception.name.rawValue) reason=\(exception.reason ?? "?") stack=\(exception.callStackSymbols.joined(separator: "\n"))")
}

func signalHandler(_ sig: Int32) {
    crashLog("Signal: \(sig)")
    exit(sig)
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = NetworkMonitor.shared
        NSSetUncaughtExceptionHandler(exceptionHandler)
        signal(SIGABRT, signalHandler)
        signal(SIGSEGV, signalHandler)
        signal(SIGBUS, signalHandler)
        signal(SIGILL, signalHandler)
        signal(SIGFPE, signalHandler)

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        let nav = UINavigationController(rootViewController: SetupViewController())
        nav.navigationBar.tintColor = UIColor(red: 145/255, green: 145/255, blue: 145/255, alpha: 1)
        window?.rootViewController = nav
        return true
    }
}
