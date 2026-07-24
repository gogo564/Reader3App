import Foundation
import Combine

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
    @Published var connectionError: Error?
    @Published var username = ""
    @Published var password = ""

    private init() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL")
    }

    var baseURL: String {
        guard let url = serverURL else { return "" }
        let trimmed = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed
    }

    func testConnection() {
        guard let url = serverURL else { return }
        let trimmed = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let requestURL = URL(string: "\(trimmed)/reader3/getBookSources") else {
            connectionError = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的服务器地址"])
            return
        }

        var request = URLRequest(url: requestURL, timeoutInterval: 10)
        if !username.isEmpty {
            let login = "\(username):\(password)"
            if let data = login.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionError = error
                    self?.isConnected = false
                    return
                }
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    self?.connectionError = nil
                    self?.isConnected = true
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    self?.connectionError = NSError(domain: "", code: Int(code),
                        userInfo: [NSLocalizedDescriptionKey: "服务器返回错误: \(code)"])
                    self?.isConnected = false
                }
            }
        }.resume()
    }

    func reset() {
        serverURL = nil
        isConnected = false
        connectionError = nil
        username = ""
        password = ""
    }
}
