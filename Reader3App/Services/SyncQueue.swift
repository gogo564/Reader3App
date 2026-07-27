import Foundation

enum SyncOpType: String, Codable {
    case saveProgress, saveBookmark, deleteBookmark
}

struct SyncOperation: Codable {
    let id: String
    let type: SyncOpType
    let bookUrl: String
    let payload: Data
}

class SyncQueue: NSObject {
    static let shared = SyncQueue()
    private override init() {}

    private var queue: [SyncOperation] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "sync_queue"),
                  let ops = try? JSONDecoder().decode([SyncOperation].self, from: data)
            else { return [] }
            return ops
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "sync_queue")
            }
        }
    }

    var pendingCount: Int { queue.count }

    func enqueue(type: SyncOpType, bookUrl: String, payload: Data) {
        let op = SyncOperation(id: UUID().uuidString, type: type, bookUrl: bookUrl, payload: payload)
        var q = queue
        q.append(op)
        queue = q
    }

    func processAll() async {
        guard NetworkMonitor.shared.isConnected else { return }
        let ops = queue
        guard !ops.isEmpty else { return }

        var serverBooks: [String: Book] = [:]
        if let books = try? await NetworkService.shared.getBookshelf() {
            for b in books { serverBooks[b.bookUrl] = b }
        }

        var remaining = ops
        for op in ops {
            do {
                if op.type == .saveProgress, let serverBook = serverBooks[op.bookUrl],
                   let localDict = (try? JSONSerialization.jsonObject(with: op.payload)) as? [String: Any],
                   let localTime = localDict["time"] as? TimeInterval,
                   let serverTime = serverBook.durChapterTime, Double(serverTime) >= localTime {
                    remaining.removeAll { $0.id == op.id }
                    continue
                }
                try await execute(op)
                remaining.removeAll { $0.id == op.id }
            } catch {
                break
            }
        }
        queue = remaining
    }

    private func execute(_ op: SyncOperation) async throws {
        switch op.type {
        case .saveProgress:
            guard let dict = try JSONSerialization.jsonObject(with: op.payload) as? [String: Any],
                  let url = dict["url"] as? String,
                  let index = dict["index"] as? Int else { return }
            let time = dict["time"] as? TimeInterval
            try await NetworkService.shared.saveBookProgress(bookUrl: url, index: index, time: time)
        case .saveBookmark:
            let item = try JSONDecoder().decode(BookmarkItem.self, from: op.payload)
            try await NetworkService.shared.saveBookmark(item)
        case .deleteBookmark:
            let item = try JSONDecoder().decode(BookmarkItem.self, from: op.payload)
            try await NetworkService.shared.deleteBookmark(item)
        }
    }

    func startAutoProcess() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(processIfOnline),
            name: .networkStatusChanged, object: nil
        )
    }

    @objc private func processIfOnline() {
        guard NetworkMonitor.shared.isConnected else { return }
        Task { await processAll() }
    }

    func clear() {
        queue = []
    }
}
