import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(Int)
    case decodeError
    case apiError(String)
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .serverError(let c): return "服务器错误: \(c)"
        case .decodeError: return "数据解析失败"
        case .apiError(let m): return m
        case .notLoggedIn: return "未登录"
        }
    }
}

struct APIResponse<T: Codable>: Codable {
    let isSuccess: Bool
    let errorMsg: String?
    let data: T?
}

class ReaderAPI {
    static let shared = ReaderAPI()

    private var baseURL: String {
        ServerManager.shared.baseURL
    }

    private var headers: [String: String] {
        var h = ["Content-Type": "application/json"]
        let mgr = ServerManager.shared
        if !mgr.username.isEmpty {
            let login = "\(mgr.username):\(mgr.password)"
            if let data = login.data(using: .utf8) {
                h["Authorization"] = "Basic \(data.base64EncodedString())"
            }
        }
        return h
    }

    private let apiPrefix = "/reader3"

    private func decode<T: Codable>(_ data: Data) throws -> T {
        let response = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        guard response.isSuccess else {
            throw APIError.apiError(response.errorMsg ?? "请求失败")
        }
        guard let result = response.data else {
            throw APIError.decodeError
        }
        return result
    }

    // MARK: - Bookshelf
    func getShelf() async throws -> [Book] {
        let data = try await get("\(apiPrefix)/getShelfBookWithCacheInfo")
        return try decode(data) as [Book]
    }

    func saveBook(book: Book) async throws {
        let body = try JSONEncoder().encode(book)
        _ = try await post("\(apiPrefix)/saveBook", body: body)
    }

    func deleteBook(bookURL: String) async throws {
        let payload = ["bookUrl": bookURL]
        let body = try JSONEncoder().encode(payload)
        _ = try await post("\(apiPrefix)/deleteBook", body: body)
    }

    // MARK: - Book Sources
    func getBookSources() async throws -> [BookSource] {
        let data = try await get("\(apiPrefix)/getBookSources")
        return try decode(data) as [BookSource]
    }

    func searchBooks(keyword: String, page: Int = 1) async throws -> [SearchResult] {
        let body = try JSONEncoder().encode(["keyword": keyword, "page": page])
        let data = try await post("\(apiPrefix)/searchBook", body: body)
        return try decode(data) as [SearchResult]
    }

    // MARK: - Book Content
    func getChapterList(bookURL: String, sourceURL: String) async throws -> [Chapter] {
        guard let encodedBook = bookURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedSource = sourceURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)\(apiPrefix)/getBookContent?url=\(encodedBook)&bookSourceUrl=\(encodedSource)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url, timeoutInterval: 30)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            throw APIError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let chapters: [Chapter] = try decode(data)
        return chapters
    }

    func getChapterContent(bookURL: String, sourceURL: String, index: Int) async throws -> String {
        guard let encodedBook = bookURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedSource = sourceURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)\(apiPrefix)/getBookContent?url=\(encodedBook)&bookSourceUrl=\(encodedSource)&index=\(index)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url, timeoutInterval: 30)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            throw APIError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let response = try JSONDecoder().decode(APIResponse<String>.self, from: data)
        guard response.isSuccess, let content = response.data else {
            throw APIError.apiError(response.errorMsg ?? "加载失败")
        }
        return content
    }

    // MARK: - Internal
    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url, timeoutInterval: 30)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            throw APIError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }

    private func post(_ path: String, body: Data) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.httpBody = body
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            throw APIError.serverError((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }
}
