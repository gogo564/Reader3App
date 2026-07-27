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

    var cachedBooks: [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: "cache_manifest"),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return dict
    }

    func cachedCount(_ bookUrl: String) -> Int { cachedBooks[bookUrl] ?? 0 }

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
        var m = cachedBooks
        m[bookUrl] = (m[bookUrl] ?? 0) + 1
        if let data = try? JSONEncoder().encode(m) {
            UserDefaults.standard.set(data, forKey: "cache_manifest")
        }
    }

    func clearCache(bookUrl: String) {
        let d = bookDir(bookUrl)
        try? FileManager.default.removeItem(at: d)
        var m = cachedBooks
        m.removeValue(forKey: bookUrl)
        if let data = try? JSONEncoder().encode(m) {
            UserDefaults.standard.set(data, forKey: "cache_manifest")
        }
    }
}
