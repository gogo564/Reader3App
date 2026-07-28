import SwiftUI

struct SetupView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var showError = false
    @State private var errorMsg = ""
    @State private var showRegister = false
    @State private var registerMsg = ""

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
                    TextField("用户名", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("密码", text: $password)
                    Button(action: login) {
                        HStack {
                            Spacer()
                            if isLoggingIn {
                                ProgressView()
                            } else {
                                Text("登 录")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(serverAddress.isEmpty || username.isEmpty || password.isEmpty || isLoggingIn)
                } header: {
                    Text("登录")
                }

                Section {
                    Button(action: register) {
                        HStack {
                            Spacer()
                            if isLoggingIn {
                                ProgressView()
                            } else {
                                Text("注册新账号")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(serverAddress.isEmpty || username.isEmpty || password.isEmpty || isLoggingIn)
                    if !registerMsg.isEmpty {
                        Text(registerMsg)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("没有账号？")
                }
            }
            .navigationTitle("阅读 3")
            .alert("登录失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMsg)
            }
        }
    }

    private func doLogin(isRegister: Bool) async throws {
        guard !serverAddress.isEmpty else { return }
        var addr = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.hasPrefix("http://") && !addr.hasPrefix("https://") {
            addr = "http://" + addr
        }
        serverManager.serverURL = addr
        try await serverManager.login(username: username, password: password)
    }

    private func login() {
        isLoggingIn = true
        registerMsg = ""
        Task {
            do {
                try await doLogin(isRegister: false)
                await MainActor.run { isLoggingIn = false }
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    showError = true
                    isLoggingIn = false
                }
            }
        }
    }

    private func register() {
        isLoggingIn = true
        registerMsg = ""
        Task {
            do {
                var addr = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                if !addr.hasPrefix("http://") && !addr.hasPrefix("https://") {
                    addr = "http://" + addr
                }
                let trimmed = addr.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard let url = URL(string: "\(trimmed)/reader3/login") else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的地址"])
                }
                var req = URLRequest(url: url, timeoutInterval: 15)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body = ["username": username, "password": password, "isLogin": false]
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, _) = try await URLSession.shared.data(for: req)
                struct RegResponse: Codable { let isSuccess: Bool; let errorMsg: String? }
                let resp = try JSONDecoder().decode(RegResponse.self, from: data)
                await MainActor.run {
                    isLoggingIn = false
                    if resp.isSuccess {
                        registerMsg = "注册成功！请登录"
                    } else {
                        registerMsg = resp.errorMsg ?? "注册失败"
                    }
                }
            } catch {
                await MainActor.run {
                    registerMsg = "注册失败: \(error.localizedDescription)"
                    isLoggingIn = false
                }
            }
        }
    }
}
