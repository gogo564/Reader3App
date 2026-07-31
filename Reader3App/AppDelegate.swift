import UIKit
import Darwin

private var crashLogFD: Int32 = -1

private var crashLogURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("crash.log")
}

func setupCrashLog() {
    crashLogFD = open(crashLogURL.path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
}

func crashLog(_ msg: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let log = "[\(formatter.string(from: Date()))] \(msg)\n"
    if let handle = try? FileHandle(forWritingTo: crashLogURL) {
        handle.seekToEndOfFile()
        handle.write(log.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? log.write(to: crashLogURL, atomically: true, encoding: .utf8)
    }
}

func exceptionHandler(_ exception: NSException) {
    crashLog("NSException: \(exception.name.rawValue) reason=\(exception.reason ?? "?") stack=\(exception.callStackSymbols.joined(separator: "\n"))")
}

func signalHandler(_ sig: Int32) {
    if crashLogFD >= 0 {
        var callstack = [UnsafeMutableRawPointer?](repeating: nil, count: 128)
        let count = backtrace(&callstack, 128)
        let header = "[\(time(nil))] Signal: \(sig)\n"
        header.withCString { _ = write(crashLogFD, $0, strlen($0)) }
        backtrace_symbols_fd(&callstack, count, crashLogFD)
    }
    signal(sig, SIG_DFL)
    raise(sig)
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = NetworkMonitor.shared
        SyncQueue.shared.startAutoProcess()
        setupCrashLog()
        NSSetUncaughtExceptionHandler(exceptionHandler)
        signal(SIGABRT, signalHandler)
        signal(SIGSEGV, signalHandler)
        signal(SIGBUS, signalHandler)
        signal(SIGILL, signalHandler)
        signal(SIGFPE, signalHandler)
        signal(SIGTRAP, signalHandler)

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        let nav = UINavigationController(rootViewController: SetupViewController())
        nav.navigationBar.tintColor = UIColor(red: 145/255, green: 145/255, blue: 145/255, alpha: 1)
        window?.rootViewController = nav
        return true
    }
}
