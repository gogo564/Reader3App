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

struct ProgressConflict: Codable {
    let opId: String
    let bookUrl: String
    let bookName: String?
    let localIndex: Int
    let localTitle: String?
    let localTime: Int64
    let serverIndex: Int
    let serverTitle: String?
    let serverTime: Int64
}

extension Notification.Name {
    static let conflictsDidChange = Notification.Name("conflictsDidChange")
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

    private var conflictStore: [ProgressConflict] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "sync_conflicts"),
                  let c = try? JSONDecoder().decode([ProgressConflict].self, from: data)
            else { return [] }
            return c
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "sync_conflicts")
            }
        }
    }

    var conflictCount: Int { conflictStore.count }
    var conflicts: [ProgressConflict] { conflictStore }

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
        var newConflicts = conflictStore
        for op in ops {
            do {
                if op.type == .saveProgress,
                   let localDict = (try? JSONSerialization.jsonObject(with: op.payload)) as? [String: Any],
                   let localTime = localDict["durChapterTime"] as? Int64,
                   let localIndex = localDict["durChapterIndex"] as? Int {
                    if let serverBook = serverBooks[op.bookUrl],
                       let serverTime = serverBook.durChapterTime {
                        if serverTime >= localTime {
                            remaining.removeAll { $0.id == op.id }
                            continue
                        }
                        if serverBook.durChapterIndex != localIndex {
                            let conflict = ProgressConflict(
                                opId: op.id, bookUrl: op.bookUrl,
                                bookName: serverBook.name,
                                localIndex: localIndex,
                                localTitle: localDict["durChapterTitle"] as? String,
                                localTime: localTime,
                                serverIndex: serverBook.durChapterIndex ?? 0,
                                serverTitle: serverBook.durChapterTitle,
                                serverTime: serverTime
                            )
                            newConflicts.append(conflict)
                            remaining.removeAll { $0.id == op.id }
                            continue
                        }
                    }
                }
                try await execute(op)
                remaining.removeAll { $0.id == op.id }
            } catch {
                break
            }
        }
        queue = remaining
        conflictStore = newConflicts
        if !newConflicts.isEmpty {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .conflictsDidChange, object: nil)
            }
        }
    }

    func resolveConflict(opId: String, useLocal: Bool) async {
        var c = conflictStore
        guard let idx = c.firstIndex(where: { $0.opId == opId }) else { return }
        let conflict = c.remove(at: idx)
        conflictStore = c

        if useLocal {
            let dict: [String: Any] = [
                "bookUrl": conflict.bookUrl,
                "durChapterIndex": conflict.localIndex,
                "durChapterTitle": conflict.localTitle ?? "",
                "durChapterTime": conflict.localTime
            ]
            if let payload = try? JSONSerialization.data(withJSONObject: dict) {
                let op = SyncOperation(id: conflict.opId, type: .saveProgress, bookUrl: conflict.bookUrl, payload: payload)
                var q = queue
                q.append(op)
                queue = q
            }
        }
        await processAll()
    }

    private func execute(_ op: SyncOperation) async throws {
        switch op.type {
        case .saveProgress:
            guard let dict = try JSONSerialization.jsonObject(with: op.payload) as? [String: Any],
                  let url = dict["bookUrl"] as? String,
                  let index = dict["durChapterIndex"] as? Int else { return }
            let title = dict["durChapterTitle"] as? String
            let time = dict["durChapterTime"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
            try await NetworkService.shared.saveBookProgress(bookUrl: url, index: index, title: title, time: time)
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
        conflictStore = []
    }
}