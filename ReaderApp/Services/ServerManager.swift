import Foundation

class ServerManager: ObservableObject {
    static let shared = ServerManager()

    @Published var serverURL: String? {
        didSet {
            if let url = serverURL {
                UserDefaults.standard.set(url, forKey: "serverURL")
            } else {
                UserDefaults.standard.removeObject(forKey: "serverURL")
            }
        }
    }
    @Published var isConnected = false
    @Published var isLoggedIn = false
    @Published var username = ""
    @Published var connectionError: Error?

    private init() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL")
    }

    var baseURL: String {
        guard let url = serverURL else { return "" }
        return url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func login(username: String, password: String) async throws {
        guard let url = serverURL else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未设置服务器地址"])
        }
        let trimmed = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let requestURL = URL(string: "\(trimmed)/reader3/login") else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的服务器地址"])
        }

        var req = URLRequest(url: requestURL, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username, "password": password, "isLogin": true]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let httpResp = resp as? HTTPURLResponse else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法连接服务器"])
        }

        struct LoginResponse: Codable {
            let isSuccess: Bool
            let errorMsg: String?
        }

        let loginResp = try JSONDecoder().decode(LoginResponse.self, from: data)
        guard loginResp.isSuccess else {
            throw NSError(domain: "", code: httpResp.statusCode,
                userInfo: [NSLocalizedDescriptionKey: loginResp.errorMsg ?? "登录失败"])
        }

        await MainActor.run {
            self.username = username
            self.isConnected = true
            self.isLoggedIn = true
            self.connectionError = nil
        }
    }

    func logout() {
        let storage = HTTPCookieStorage.shared
        if let url = serverURL.flatMap({ URL(string: $0) }) {
            storage.cookies(for: url)?.forEach { storage.deleteCookie($0) }
        }
        username = ""
        isConnected = false
        isLoggedIn = false
        connectionError = nil
    }

    func reset() {
        logout()
        serverURL = nil
    }
}
Cg==
