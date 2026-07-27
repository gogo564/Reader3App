import Foundation

class CacheManager {
    static let shared = CacheManager()

    private var cacheDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let c = dir.appendingPathComponent("Caches")
        try? FileManager.default.createDirectory(at: c, withIntermediateDirectories: true)
        return c
    }

    private func bookDir(_ bookUrl: String) -> URL {
        let key = String(bookUrl.hashValue)
        let d = cacheDir.appendingPathComponent(key)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func totalKey(_ bookUrl: String) -> String { "cache_total_\(bookUrl)" }

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

    func clearCache(bookUrl: String) {
        let d = bookDir(bookUrl)
        try? FileManager.default.removeItem(at: d)
        UserDefaults.standard.removeObject(forKey: totalKey(bookUrl))
    }
}
