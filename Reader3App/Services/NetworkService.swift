import Foundation

enum APIError: LocalizedError {
    case invalidURL, networkError(Error), serverError(Int)
    case decodeError(String), apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .serverError(let c): return "服务器错误: \(c)"
        case .decodeError(let m): return "数据解析失败: \(m)"
        case .apiError(let m): return m
        }
    }
}

class NetworkService {
    static let shared = NetworkService()
    private init() {}

    private var appState: AppState { AppState.shared }

    // MARK: - Auth
    func login(username: String, password: String, isLogin: Bool = true) async throws -> LoginResult {
        let body = try JSONSerialization.data(withJSONObject: [
            "username": username, "password": password, "isLogin": isLogin
        ])
        let data = try await post("/login", body: body)
        let resp = try JSONDecoder().decode(APIResponse<LoginResult>.self, from: data)
        guard resp.isSuccess, let result = resp.data else {
            throw APIError.apiError(resp.errorMsg ?? "请求失败")
        }
        return result
    }

    // MARK: - User Info
    func getUserInfo() async throws -> UserInfo {
        let data = try await get("/getUserInfo")
        return try decode(data)
    }

    // MARK: - Bookshelf
    func getBookshelf(refresh: Bool = false) async throws -> [Book] {
        let data = try await get("/getBookshelf", query: ["refresh": refresh ? "1" : "0"])
        return try decode(data)
    }

    func saveBook(_ book: Book) async throws -> Book {
        let body = try JSONEncoder().encode(book)
        let data = try await post("/saveBook", body: body)
        return try decode(data)
    }

    func deleteBook(bookUrl: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["bookUrl": bookUrl])
        _ = try await post("/deleteBook", body: body)
    }

    // MARK: - Book Groups
    func getBookGroups() async throws -> [BookGroup] {
        let data = try await get("/getBookGroups")
        return try decode(data)
    }

    // MARK: - Book Sources
    func getBookSources(simple: Bool = true) async throws -> [BookSource] {
        let data = try await get("/getBookSources", query: ["simple": "1"])
        return try decode(data)
    }

    func getAvailableBookSource(bookUrl: String, refresh: Bool = false) async throws -> [SearchResult] {
        let body = try JSONSerialization.data(withJSONObject: ["url": bookUrl, "refresh": refresh ? 1 : 0])
        let data = try await post("/getAvailableBookSource", body: body)
        return try decode(data)
    }

    func setBookSource(bookUrl: String, newUrl: String, bookSourceUrl: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "bookUrl": bookUrl, "newUrl": newUrl, "bookSourceUrl": bookSourceUrl
        ])
        _ = try await post("/setBookSource", body: body)
    }

    // MARK: - Search
    func searchBook(key: String, searchType: String, bookSourceUrl: String = "",
                    bookSourceGroup: String = "", concurrentCount: Int = 24,
                    page: Int = 1, lastIndex: Int = -1) async throws -> [SearchResult] {
        let body = try JSONSerialization.data(withJSONObject: [
            "key": key,
            "bookSourceUrl": bookSourceUrl,
            "bookSourceGroup": bookSourceGroup,
            "concurrentCount": concurrentCount,
            "lastIndex": lastIndex,
            "page": page
        ])
        let path = searchType == "single" ? "/searchBook" : "/searchBookMulti"
        let data = try await post(path, body: body, timeout: searchType == "single" ? 30 : 180)
        let resp = try JSONDecoder().decode(APIResponse<SearchMultiResponse>.self, from: data)
        guard resp.isSuccess, let result = resp.data else {
            throw APIError.apiError(resp.errorMsg ?? "搜索失败")
        }
        return result.list
    }

    // MARK: - Reading
    func getChapterList(bookUrl: String, bookSourceUrl: String? = nil, refresh: Bool = false) async throws -> [Chapter] {
        var query: [String: String] = ["url": bookUrl, "refresh": refresh ? "1" : "0"]
        if let src = bookSourceUrl { query["bookSourceUrl"] = src }
        let data = try await get("/getChapterList", query: query)
        return try decode(data)
    }

    func getBookContent(bookUrl: String, index: Int, refresh: Bool = false, cache: Bool = false) async throws -> String {
        var query: [String: String] = ["url": bookUrl, "index": String(index)]
        if refresh { query["refresh"] = "1" }
        if cache { query["cache"] = "1" }
        let data = try await get("/getBookContent", query: query)
        let resp = try JSONDecoder().decode(APIResponse<String>.self, from: data)
        guard resp.isSuccess, let content = resp.data else {
            throw APIError.apiError(resp.errorMsg ?? "获取内容失败")
        }
        return content
    }

    func saveBookProgress(bookUrl: String, index: Int, title: String? = nil, bookName: String? = nil, time: Int64) async throws {
        var book = CacheManager.shared.findCachedBook(bookUrl: bookUrl)
        if book == nil {
            let books = try await getBookshelf()
            book = books.first(where: { $0.bookUrl == bookUrl })
        }
        guard var b = book else {
            let b = Book(bookUrl: bookUrl, name: bookName ?? "", author: nil, durChapterTitle: title, durChapterIndex: index, durChapterTime: time)
            _ = try await saveBook(b)
            return
        }
        b = b.withProgress(index: index, title: title, time: time)
        _ = try await saveBook(b)
    }

    // MARK: - Bookmarks
    func getBookmarks() async throws -> [BookmarkItem] {
        let data = try await get("/getBookmarks")
        return try decode(data)
    }

    func saveBookmark(_ bookmark: BookmarkItem) async throws {
        let body = try JSONEncoder().encode(bookmark)
        _ = try await post("/saveBookmark", body: body)
    }

    func deleteBookmark(_ bookmark: BookmarkItem) async throws {
        let body = try JSONEncoder().encode(bookmark)
        _ = try await post("/deleteBookmark", body: body)
    }

    func deleteBookmarks(_ bookmarks: [BookmarkItem]) async throws {
        let body = try JSONEncoder().encode(bookmarks)
        _ = try await post("/deleteBookmarks", body: body)
    }

    // MARK: - Replace Rules
    func getReplaceRules() async throws -> [ReplaceRule] {
        let data = try await get("/getReplaceRules")
        return try decode(data)
    }

    func saveReplaceRule(_ rule: ReplaceRule) async throws {
        let body = try JSONEncoder().encode(rule)
        _ = try await post("/saveReplaceRule", body: body)
    }

    func deleteReplaceRule(_ rule: ReplaceRule) async throws {
        let body = try JSONEncoder().encode(rule)
        _ = try await post("/deleteReplaceRule", body: body)
    }

    // MARK: - Explore
    func exploreBook(bookSourceUrl: String) async throws -> [SearchResult] {
        let body = try JSONEncoder().encode(["bookSourceUrl": bookSourceUrl])
        let data = try await post("/exploreBook", body: body)
        return try decode(data)
    }

    // MARK: - Test Connection
    func testConnection(serverURL: String) async throws {
        guard let url = URL(string: "\(serverURL)/reader3/getBookSources") else {
            throw APIError.invalidURL
        }
        let (_, resp) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 10))
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - Private
    private func decode<T: Codable>(_ data: Data) throws -> T {
        let resp = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard resp.isSuccess else { throw APIError.apiError(resp.errorMsg ?? "请求失败") }
        guard let result = resp.data else { throw APIError.decodeError("data 为空") }
        return result
    }

    private func buildURL(_ path: String, query: [String: String]? = nil) throws -> URL {
        var comps = URLComponents(string: "\(appState.apiURL)\(path)")
        var items = query?.map { URLQueryItem(name: $0.key, value: $0.value) } ?? []
        if !appState.accessToken.isEmpty {
            items.append(URLQueryItem(name: "accessToken", value: appState.accessToken))
        }
        if !items.isEmpty { comps?.queryItems = items }
        guard let url = comps?.url else { throw APIError.invalidURL }
        return url
    }

    private let headers = ["Content-Type": "application/json"]

    private func get(_ path: String, query: [String: String]? = nil) async throws -> Data {
        let url = try buildURL(path, query: query)
        var req = URLRequest(url: url, timeoutInterval: 30)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }

    private func post(_ path: String, body: Data, query: [String: String]? = nil, timeout: TimeInterval = 30) async throws -> Data {
        let url = try buildURL(path, query: query)
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.httpBody = body
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }
}

extension JSONEncoder {
    convenience init(_ strategy: KeyEncodingStrategy) {
        self.init()
        keyEncodingStrategy = strategy
    }
}

extension Data {
    init<T: Encodable>(from value: T) throws {
        self = try JSONEncoder().encode(value)
    }
}
