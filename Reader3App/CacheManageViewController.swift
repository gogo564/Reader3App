import UIKit

class CacheManageViewController: UIViewController {
    private var books: [Book] = []
    private weak var shelfVC: ShelfViewController?
    private var tableView: UITableView!
    private var cacheTasks: [String: CacheTask] = [:]

    private class CacheTask {
        let book: Book
        var isPaused = false
        var isCancelled = false
        var currentIndex = 0
        var total = 0

        init(book: Book) { self.book = book }
    }

    init(books: [Book], shelfVC: ShelfViewController) {
        self.books = books
        self.shelfVC = shelfVC
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "缓存管理"
        view.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        setupTableView()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .done, target: self, action: #selector(dismissSelf))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "全部缓存", style: .plain, target: self, action: #selector(cacheAll))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    deinit { cancelAllTasks() }

    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    func updateBooks(_ books: [Book]) {
        self.books = books
        if isViewLoaded { tableView.reloadData() }
    }

    @objc private func cacheAll() {
        for book in books {
            let cached = CacheManager.shared.cachedCount(book.bookUrl)
            let total = CacheManager.shared.cachedTotal(book.bookUrl)
            if total > 0 && cached >= total { continue }
            startCaching(book)
        }
    }

    private func startCaching(_ book: Book) {
        guard NetworkMonitor.shared.isConnected else {
            let alert = UIAlertController(title: "缓存失败", message: "当前无网络连接", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            return
        }
        if cacheTasks[book.bookUrl] != nil { return }
        let task = CacheTask(book: book)
        cacheTasks[book.bookUrl] = task
        tableView.reloadData()
        performCaching(task)
    }

    private func performCaching(_ task: CacheTask) {
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
                        await MainActor.run { [weak self] in self?.reloadVisibleRow(bookUrl: task.book.bookUrl) }
                        continue
                    }
                    let content = try await NetworkService.shared.getBookContent(bookUrl: task.book.bookUrl, index: i)
                    CacheManager.shared.cacheChapter(bookUrl: task.book.bookUrl, index: i, content: content)
                    task.currentIndex = i + 1
                    await MainActor.run { [weak self] in self?.reloadVisibleRow(bookUrl: task.book.bookUrl) }
                }
                await MainActor.run { [weak self] in
                    self?.cacheTasks.removeValue(forKey: task.book.bookUrl)
                    self?.tableView.reloadData()
                    self?.shelfVC?.loadBooks()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.cacheTasks.removeValue(forKey: task.book.bookUrl)
                    self?.tableView.reloadData()
                }
            }
        }
    }

    private func reloadVisibleRow(bookUrl: String) {
        guard let idx = books.firstIndex(where: { $0.bookUrl == bookUrl }),
              let cells = tableView.visibleCells as? [UITableViewCell],
              idx + 1 < cells.count + (tableView.numberOfRows(inSection: 0) - books.count) else { return }
        tableView.reloadRows(at: [IndexPath(row: idx + 1, section: 0)], with: .none)
    }

    private func cancelAllTasks() {
        for task in cacheTasks.values {
            task.isCancelled = true
        }
        cacheTasks.removeAll()
    }

    private func clearCache(_ book: Book) {
        let alert = UIAlertController(title: "清除缓存", message: "确定清除「\(book.name)」的本地缓存吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            CacheManager.shared.clearCache(bookUrl: book.bookUrl)
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    @objc private func deleteTapped(_ sender: UIView) {
        let row = sender.tag
        guard row > 0, row - 1 < books.count else { return }
        clearCache(books[row - 1])
    }
}

extension CacheManageViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        if books.isEmpty { return 1 }
        return books.count + 1
    }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let reuseId = books.isEmpty || ip.row == 0 ? "cell" : "subtitle"
        let cell: UITableViewCell
        if let c = tv.dequeueReusableCell(withIdentifier: reuseId) {
            cell = c
        } else {
            cell = UITableViewCell(style: reuseId == "subtitle" ? .subtitle : .default, reuseIdentifier: reuseId)
        }
        if ip.row > 0, reuseId == "subtitle" {
            let book = books[ip.row - 1]
            let cached = CacheManager.shared.cachedCount(book.bookUrl)
            let task = cacheTasks[book.bookUrl]
            if task == nil, cached > 0 {
                let btn = UIButton(type: .system)
                btn.setImage(UIImage(systemName: "trash"), for: .normal)
                btn.tintColor = .systemRed
                btn.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
                btn.tag = ip.row
                btn.addTarget(self, action: #selector(deleteTapped(_:)), for: .touchUpInside)
                cell.accessoryView = btn
            } else {
                cell.accessoryView = nil
            }
        } else {
            cell.accessoryView = nil
        }
        if books.isEmpty {
            cell.textLabel?.text = "暂无书籍"
            cell.textLabel?.textColor = .secondaryLabel
            cell.textLabel?.textAlignment = .center
            cell.selectionStyle = .none
            cell.backgroundColor = .white
            return cell
        }
        if ip.row == 0 {
            let pending = SyncQueue.shared.pendingCount
            cell.textLabel?.text = pending > 0
                ? "同步队列: \(pending) 个待同步操作 ⏳"
                : "同步队列: 无待同步操作 ✅"
            cell.textLabel?.textColor = .systemBlue
            cell.textLabel?.font = .systemFont(ofSize: 14)
            cell.backgroundColor = UIColor(white: 1, alpha: 0.7)
            cell.selectionStyle = .none
            return cell
        }
        let book = books[ip.row - 1]
        let cached = CacheManager.shared.cachedCount(book.bookUrl)
        let total = CacheManager.shared.cachedTotal(book.bookUrl)
        let task = cacheTasks[book.bookUrl]

        cell.textLabel?.text = book.name
        cell.backgroundColor = .white

        if let t = task {
            if t.isPaused {
                cell.detailTextLabel?.text = "已暂停 \(t.currentIndex)/\(t.total) 章"
                cell.textLabel?.textColor = .systemOrange
            } else {
                cell.detailTextLabel?.text = "缓存中 \(t.currentIndex)/\(t.total) 章"
                cell.textLabel?.textColor = .systemBlue
            }
            cell.selectionStyle = .default
        } else if total > 0 && cached >= total {
            cell.detailTextLabel?.text = "已缓存 \(cached)/\(total) 章 ✅"
            cell.textLabel?.textColor = .darkText
            cell.selectionStyle = .none
        } else if total > 0 {
            cell.detailTextLabel?.text = "已缓存 \(cached)/\(total) 章"
            cell.textLabel?.textColor = .darkText
            cell.selectionStyle = .default
        } else {
            cell.detailTextLabel?.text = cached > 0 ? "已缓存 \(cached) 章（部分）" : "未缓存"
            cell.textLabel?.textColor = .darkText
            cell.selectionStyle = .default
        }
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt ip: IndexPath) {
        guard ip.row > 0 else { return }
        let book = books[ip.row - 1]
        if let task = cacheTasks[book.bookUrl] {
            task.isPaused.toggle()
            tableView.reloadData()
        } else {
            let cached = CacheManager.shared.cachedCount(book.bookUrl)
            let total = CacheManager.shared.cachedTotal(book.bookUrl)
            if total > 0 && cached >= total {
                clearCache(book)
            } else {
                startCaching(book)
            }
        }
    }

    func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt ip: IndexPath) -> UISwipeActionsConfiguration? {
        guard ip.row > 0 else { return nil }
        let book = books[ip.row - 1]
        if cacheTasks[book.bookUrl] != nil { return nil }
        let cached = CacheManager.shared.cachedCount(book.bookUrl)
        guard cached > 0 else { return nil }
        let clear = UIContextualAction(style: .destructive, title: "清除") { [weak self] _, _, done in
            self?.clearCache(book)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [clear])
    }
}
