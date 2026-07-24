import SwiftUI

@main
struct ReaderApp: App {
    @StateObject private var serverManager = ServerManager.shared

    var body: some Scene {
        WindowGroup {
            if serverManager.serverURL == nil {
                SetupView()
                    .environmentObject(serverManager)
            } else if !serverManager.isConnected {
                LoadingView()
                    .environmentObject(serverManager)
                    .onAppear { serverManager.testConnection() }
            } else {
                MainTabView()
                    .environmentObject(serverManager)
            }
        }
    }
}

struct LoadingView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在连接服务器...")
                .foregroundColor(.secondary)
        }
        .onReceive(serverManager.$connectionError) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert("连接失败", isPresented: $showError) {
            Button("重新连接") { serverManager.testConnection() }
            Button("重新设置") { serverManager.reset() }
        } message: {
            Text(errorMessage)
        }
    }
}
