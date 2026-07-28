import UIKit
import Foundation

class CacheTaskManager {
    static let shared = CacheTaskManager()

    private var cacheTasks: [String: CacheTask] = [:]

    static let progressNotification = Notification.Name("CacheTaskProgress")
    static let completedNotification = Notification.Name("CacheTaskCompleted")
    static let failedNotification = Notification.Name("CacheTaskFailed")

    private class CacheTask {
        let book: Book
        var isPaused = false
        var isCancelled = false
        var currentIndex = 0
        var total = 0
        init(book: Book) { self.book = book }
    }

    func state(for bookUrl: String) -> (isPaused: Bool, currentIndex: Int, total: Int)? {
        guard let t = cacheTasks[bookUrl] else { return nil }
        return (t.isPaused, t.currentIndex, t.total)
    }

    func isCaching(_ bookUrl: String) -> Bool { cacheTasks[bookUrl] != nil }

    func start(_ book: Book) {
        guard NetworkMonitor.shared.isConnected else { return }
        if cacheTasks[book.bookUrl] != nil { return }
        let task = CacheTask(book: book)
        cacheTasks[book.bookUrl] = task
        perform(task)
    }

    func togglePause(_ bookUrl: String) {
        cacheTasks[bookUrl]?.isPaused.toggle()
    }

    func cancelAll() {
        for t in cacheTasks.values { t.isCancelled = true }
        cacheTasks.removeAll()
    }

    func cancel(_ bookUrl: String) {
        cacheTasks[bookUrl]?.isCancelled = true
        cacheTasks.removeValue(forKey: bookUrl)
    }

    private func perform(_ task: CacheTask) {
        Task {
            do {
                let chapters = try await NetworkService.shared.getChapterList(bookUrl: task.book.bookUrl)
                task.total = chapters.count
                CacheManager.shared.setCachedTotal(task.book.bookUrl, total: task.total)
                CacheManager.shared.cacheChapters(bookUrl: task.book.bookUrl, chapters: chapters)
                for i in task.currentIndex..<task.total {
                    if task.isCancelled { return }
                    while task.isPaused {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        if task.isCancelled { return }
                    }
                    if CacheManager.shared.isChapterCached(bookUrl: task.book.bookUrl, index: i) {
                        task.currentIndex = i + 1
                        await MainActor.run { postProgress(task) }
                        continue
                    }
                    let content = try await NetworkService.shared.getBookContent(bookUrl: task.book.bookUrl, index: i)
                    CacheManager.shared.cacheChapter(bookUrl: task.book.bookUrl, index: i, content: content)
                    task.currentIndex = i + 1
                    await MainActor.run { postProgress(task) }
                }
                await MainActor.run {
                    cacheTasks.removeValue(forKey: task.book.bookUrl)
                    NotificationCenter.default.post(name: Self.completedNotification, object: nil, userInfo: ["bookUrl": task.book.bookUrl])
                }
            } catch {
                await MainActor.run {
                    cacheTasks.removeValue(forKey: task.book.bookUrl)
                    NotificationCenter.default.post(name: Self.failedNotification, object: nil, userInfo: ["bookUrl": task.book.bookUrl])
                }
            }
        }
    }

    private func postProgress(_ task: CacheTask) {
        NotificationCenter.default.post(
            name: Self.progressNotification,
            object: nil,
            userInfo: ["bookUrl": task.book.bookUrl, "currentIndex": task.currentIndex, "total": task.total]
        )
    }
}
