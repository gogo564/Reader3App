import SwiftUI

@main
struct ReaderApp: App {
    @StateObject private var serverManager = ServerManager.shared

    var body: some Scene {
        WindowGroup {
            if serverManager.serverURL == nil {
                SetupView()
                    .environmentObject(serverManager)
            } else if !serverManager.isLoggedIn {
                SetupView()
                    .environmentObject(serverManager)
            } else {
                MainTabView()
                    .environmentObject(serverManager)
            }
        }
    }
}
