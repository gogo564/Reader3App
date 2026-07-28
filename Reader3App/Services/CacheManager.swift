import UIKit

class CacheManager {
    static let shared = CacheManager()

    private var cacheDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let c = dir.appendingPathComponent("Caches")
        try? FileManager.default.createDirectory(at: c, withIntermediateDirectories: true)
        return c
    }

    private func stableKey(_ bookUrl: String) -> String {
        bookUrl.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func bookDir(_ bookUrl: String) -> URL {
        let key = stableKey(bookUrl)
        let d = cacheDir.appendingPathComponent(key)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private var metaDir: URL {
        let d = cacheDir.appendingPathComponent("meta")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private var coverDir: URL {
        let d = cacheDir.appendingPathComponent("covers")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func totalKey(_ bookUrl: String) -> String { "cache_total_\(bookUrl)" }

    func cacheChapters(bookUrl: String, chapters: [Chapter]) {
        let f = bookDir(bookUrl).appendingPathComponent("chapters.json")
        if let data = try? JSONEncoder().encode(chapters) {
            try? data.write(to: f)
        }
    }

    func getCachedChapters(bookUrl: String) -> [Chapter]? {
        let f = bookDir(bookUrl).appendingPathComponent("chapters.json")
        guard let data = try? Data(contentsOf: f) else { return nil }
        return try? JSONDecoder().decode([Chapter].self, from: data)
    }

    func cacheBookshelf(_ books: [Book]) {
        let f = metaDir.appendingPathComponent("bookshelf.json")
        if let data = try? JSONEncoder().encode(books) {
            try? data.write(to: f)
        }
    }

    func getCachedBookshelf() -> [Book]? {
        let f = metaDir.appendingPathComponent("bookshelf.json")
        guard let data = try? Data(contentsOf: f) else { return nil }
        return try? JSONDecoder().decode([Book].self, from: data)
    }

    func cacheCover(bookUrl: String, imageData: Data) {
        let f = coverDir.appendingPathComponent("\(stableKey(bookUrl)).jpg")
        try? imageData.write(to: f)
    }

    func getCachedCover(bookUrl: String) -> UIImage? {
        let f = coverDir.appendingPathComponent("\(stableKey(bookUrl)).jpg")
        guard let data = try? Data(contentsOf: f) else { return nil }
        return UIImage(data: data)
    }

    func cachedCount(_ bookUrl: String) -> Int {
        let d = bookDir(bookUrl)
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: d.path) else { return 0 }
        return files.filter { $0.hasSuffix(".txt") }.count
    }

    func cachedTotal(_ bookUrl: String) -> Int {
        UserDefaults.standard.integer(forKey: totalKey(bookUrl))
    }

    func setCachedTotal(_ bookUrl: String, total: Int) {
        UserDefaults.standard.set(total, forKey: totalKey(bookUrl))
    }

    func isFullyCached(bookUrl: String) -> Bool {
        let total = cachedTotal(bookUrl)
        guard total > 0 else { return false }
        return cachedCount(bookUrl) >= total
    }

    func isChapterCached(bookUrl: String, index: Int) -> Bool {
        let f = bookDir(bookUrl).appendingPathComponent("\(index).txt")
        return FileManager.default.fileExists(atPath: f.path)
    }

    func getCachedChapter(bookUrl: String, index: Int) -> String? {
        let f = bookDir(bookUrl).appendingPathComponent("\(index).txt")
        return try? String(contentsOf: f, encoding: .utf8)
    }

    func cacheChapter(bookUrl: String, index: Int, content: String) {
        let f = bookDir(bookUrl).appendingPathComponent("\(index).txt")
        try? content.write(to: f, atomically: true, encoding: .utf8)
    }

    func updateBookProgress(bookUrl: String, bookName: String, index: Int, chapterTitle: String?, time: Int64) {
        var books = getCachedBookshelf() ?? []
        if let idx = books.firstIndex(where: { $0.bookUrl == bookUrl }) {
            books[idx] = books[idx].withProgress(index: index, title: chapterTitle, time: time)
        } else {
            let b = Book(bookUrl: bookUrl, name: bookName, author: nil, durChapterTitle: chapterTitle, durChapterIndex: index, durChapterTime: time)
            books.append(b)
        }
        cacheBookshelf(books)
    }

    func findCachedBook(bookUrl: String) -> Book? {
        getCachedBookshelf()?.first(where: { $0.bookUrl == bookUrl })
    }

    func clearCache(bookUrl: String) {
        let d = bookDir(bookUrl)
        try? FileManager.default.removeItem(at: d)
        UserDefaults.standard.removeObject(forKey: totalKey(bookUrl))
    }
}
