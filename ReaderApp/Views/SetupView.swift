import SwiftUI

struct SetupView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var serverAddress = ""
    @State private var useAuth = false
    @State private var username = ""
    @State private var password = ""
    @State private var isTesting = false
    @State private var showError = false
    @State private var errorMsg = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("服务器地址", text: $serverAddress)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .placeholder(when: serverAddress.isEmpty) {
                            Text("例如: http://192.168.1.85:4396")
                                .foregroundColor(.secondary)
                        }
                } header: {
                    Text("连接你的 Reader 服务器")
                } footer: {
                    Text("请输入 Reader 服务器的完整地址，包括 http:// 和端口号")
                }

                Section {
                    Toggle("需要登录", isOn: $useAuth)
                    if useAuth {
                        TextField("用户名", text: $username)
                            .autocapitalization(.none)
                        SecureField("密码", text: $password)
                    }
                } header: {
                    Text("身份验证（可选）")
                }

                Section {
                    Button(action: testConnection) {
                        HStack {
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else {
                                Text("连接服务器")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(serverAddress.isEmpty || isTesting)
                }
            }
            .navigationTitle("设置")
            .alert("连接失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMsg)
            }
        }
    }

    private func testConnection() {
        guard !serverAddress.isEmpty else { return }
        isTesting = true
        var addr = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.hasPrefix("http://") && !addr.hasPrefix("https://") {
            addr = "http://" + addr
        }
        serverManager.serverURL = addr
        serverManager.username = useAuth ? username : ""
        serverManager.password = useAuth ? password : ""
        serverManager.testConnection()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak serverManager] in
            guard let mgr = serverManager else { return }
            isTesting = false
            if !mgr.isConnected {
                errorMsg = mgr.connectionError?.localizedDescription ?? "无法连接到服务器，请检查地址和网络"
                showError = true
            }
        }
    }
}

extension View {
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder content: () -> Content) -> some View {
        overlay(alignment: .leading) {
            if shouldShow { content() }
        }
    }
}
