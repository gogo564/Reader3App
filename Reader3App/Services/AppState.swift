import Foundation

class AppState {
    static let shared = AppState()
    private init() {}

    var serverURL: String = ""
    var isConnected: Bool = false
    var isLoggedIn: Bool = false

    var apiURL: String { "\(serverURL)/reader3" }
    var baseURL: String { serverURL }
    var accessToken: String { "" }

    private let pendingDeleteKey = "pendingDeletes"

    var pendingDeletes: [String] {
        get { UserDefaults.standard.stringArray(forKey: pendingDeleteKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: pendingDeleteKey) }
    }

    func addPendingDelete(bookUrl: String) {
        var list = pendingDeletes
        if !list.contains(bookUrl) {
            list.append(bookUrl)
            pendingDeletes = list
        }
    }

    func removePendingDelete(bookUrl: String) {
        pendingDeletes = pendingDeletes.filter { $0 != bookUrl }
    }

    func syncPendingDeletes() async {
        let list = pendingDeletes
        guard !list.isEmpty else { return }
        for bookUrl in list {
            do {
                try await NetworkService.shared.deleteBook(bookUrl: bookUrl)
                await MainActor.run { removePendingDelete(bookUrl: bookUrl) }
            } catch {
                return
            }
        }
    }
}
