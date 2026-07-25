import Foundation

class AppState {
    static let shared = AppState()
    private init() {}

    var serverURL: String = ""
    var isConnected: Bool = false

    var apiURL: String { "\(serverURL)/reader3" }
    var baseURL: String { serverURL }
    var accessToken: String { "" }
}
