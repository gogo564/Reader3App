import Foundation

enum APIError: LocalizedError {
    case invalidURL, networkError(Error), serverError(Int)
    case decodeError(String), apiError(String), notLoggedIn

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .serverError(let c): return "服务器错误: \(c)"
        case .decodeError(let m): return "数据解析失败: \(m)"
        case .apiError(let m): return m
        case .notLoggedIn: return "未登录，请重新登录"
        }
    }
}

final class NetworkService: @unchecked Sendable {
    static let shared = NetworkService()
    private init() {}

    private var appState: AppState { AppState.shared }

    // MARK: - Auth
    func login(username: String, password: String, isLogin: Bool = true) async throws -> LoginResult {
        let body = try JSONSerialization.data(withJSONObject: [
            "username": username, "password": password, "isLogin": isLogin
        ] as [String: Any])
        let data = try await post("/login", body: body)
        let resp = try JSONDecoder().decode(APIResponse<LoginResult>.self, from: data)
        guard resp.isSuccess, let result = resp.data else {
            throw APIError.apiError(resp.errorMsg ?? "请求失败")
        }
        return result
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

    // MARK: - Book Sources
    func getBookSources(simple: Bool = true) async throws -> [BookSource] {
        let data = try await get("/getBookSources", query: ["simple": "1"])
        return try decode(data)
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
        ] as [String: Any])
        let path = searchType == "single" ? "/searchBook" : "/searchBookMulti"
        let data = try await post(path, body: body, timeout: searchType == "single" ? 30 : 180)
        if searchType == "single" {
            let resp = try JSONDecoder().decode(APIResponse<[SearchResult]>.self, from: data)
            guard resp.isSuccess, let result = resp.data else {
                throw APIError.apiError(resp.errorMsg ?? "搜索失败")
            }
            return result
        } else {
            let resp = try JSONDecoder().decode(APIResponse<SearchMultiResponse>.self, from: data)
            guard resp.isSuccess, let result = resp.data else {
                throw APIError.apiError(resp.errorMsg ?? "搜索失败")
            }
            return result.list
        }
    }

    // MARK: - Reading
    func getChapterList(bookUrl: String, bookSourceUrl: String? = nil, refresh: Bool = false, timeout: TimeInterval = 30) async throws -> [Chapter] {
        var query: [String: String] = ["url": bookUrl, "refresh": refresh ? "1" : "0"]
        if let src = bookSourceUrl { query["bookSourceUrl"] = src }
        let data = try await get("/getChapterList", query: query, timeout: timeout)
        return try decode(data)
    }

    func getBookContent(bookUrl: String, index: Int, refresh: Bool = false) async throws -> String {
        var query: [String: String] = ["url": bookUrl, "index": String(index)]
        if refresh { query["refresh"] = "1" }
        for attempt in 0..<2 {
            let data = try await get("/getBookContent", query: query)
            let resp = try JSONDecoder().decode(APIResponse<String>.self, from: data)
            guard resp.isSuccess, let content = resp.data else {
                let msg = resp.errorMsg ?? "获取内容失败"
                if attempt == 0 && (msg.localizedCaseInsensitiveContains("timeout") || msg.localizedCaseInsensitiveContains("timed out")) {
                    continue
                }
                throw APIError.apiError(msg)
            }
            return content
        }
        throw APIError.apiError("获取内容超时，请稍后重试")
    }

    // MARK: - Auto Source Switch

    func searchOnSource(bookName: String, sourceUrl: String, timeout: TimeInterval = 30) async throws -> [SearchResult] {
        let body = try JSONSerialization.data(withJSONObject: [
            "key": bookName,
            "bookSourceUrl": sourceUrl,
            "concurrentCount": 1,
            "page": 1,
            "lastIndex": -1
        ] as [String: Any])
        let data = try await post("/searchBook", body: body, timeout: timeout)
        let resp = try JSONDecoder().decode(APIResponse<[SearchResult]>.self, from: data)
        guard resp.isSuccess, let result = resp.data else {
            throw APIError.apiError(resp.errorMsg ?? "搜索失败")
        }
        return result
    }

    func autoSwitchSource(for book: Book) async throws -> Book? {
        let sources = try await getBookSources()
        let currentOrigin = book.origin ?? ""
        for src in sources {
            guard let srcUrl = src.bookSourceUrl, !srcUrl.isEmpty else { continue }
            if srcUrl == currentOrigin { continue }
            guard let results = try? await searchOnSource(bookName: book.name, sourceUrl: srcUrl) else { continue }
            for r in results {
                guard r.name == book.name else { continue }
                if let author = book.author, !author.isEmpty, r.author != author { continue }
                return Book(bookUrl: r.bookUrl, name: r.name, author: r.author,
                            coverUrl: r.coverUrl, origin: r.origin, originName: r.originName,
                            intro: r.intro,
                            durChapterTitle: book.durChapterTitle,
                            durChapterIndex: book.durChapterIndex,
                            durChapterTime: book.durChapterTime,
                            latestChapterTitle: r.latestChapterTitle,
                            type: r.type, tocUrl: r.tocUrl)
            }
        }
        return nil
    }

    func saveBookProgress(bookUrl: String, index: Int, title: String? = nil, bookName: String? = nil, time: Int64, pos: Int? = nil) async throws {
        var book = CacheManager.shared.findCachedBook(bookUrl: bookUrl)
        if book == nil {
            let books = try await getBookshelf()
            book = books.first(where: { $0.bookUrl == bookUrl })
        }
        guard var b = book else {
            let b = Book(bookUrl: bookUrl, name: bookName ?? "", author: nil, durChapterTitle: title, durChapterIndex: index, durChapterTime: time, durChapterPos: pos)
            _ = try await saveBook(b)
            return
        }
        b = b.withProgress(index: index, title: title, time: time, pos: pos)
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

    // MARK: - Private
    private func decode<T: Codable>(_ data: Data) throws -> T {
        let resp = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard resp.isSuccess else {
            if resp.errorMsg == "请登录后使用" || resp.errorMsg == "NEED_LOGIN" {
                DispatchQueue.main.async { AppState.shared.isLoggedIn = false }
                throw APIError.notLoggedIn
            }
            throw APIError.apiError(resp.errorMsg ?? "请求失败")
        }
        guard let result = resp.data else { throw APIError.decodeError("data 为空") }
        return result
    }

    private func buildURL(_ path: String, query: [String: String]? = nil) throws -> URL {
        var comps = URLComponents(string: "\(appState.apiURL)\(path)")
        let items = query?.map { URLQueryItem(name: $0.key, value: $0.value) } ?? []
        if !items.isEmpty { comps?.queryItems = items }
        guard let url = comps?.url else { throw APIError.invalidURL }
        return url
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }()

    private func get(_ path: String, query: [String: String]? = nil, timeout: TimeInterval = 30) async throws -> Data {
        let url = try buildURL(path, query: query)
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.serverError(0)
        }
        if http.statusCode == 401 {
            DispatchQueue.main.async { AppState.shared.isLoggedIn = false }
            throw APIError.notLoggedIn
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode)
        }
        return data
    }

    private func post(_ path: String, body: Data, query: [String: String]? = nil, timeout: TimeInterval = 30) async throws -> Data {
        let url = try buildURL(path, query: query)
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.serverError(0)
        }
        if http.statusCode == 401 {
            DispatchQueue.main.async { AppState.shared.isLoggedIn = false }
            throw APIError.notLoggedIn
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode)
        }
        return data
    }
}
