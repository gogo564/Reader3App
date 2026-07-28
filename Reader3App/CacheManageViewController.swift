import UIKit

class CacheManageViewController: UIViewController {
    private var books: [Book] = []
    private weak var shelfVC: ShelfViewController?
    private var tableView: UITableView!

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
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleProgress(_:)), name: CacheTaskManager.progressNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleCompleted(_:)), name: CacheTaskManager.completedNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleFailed(_:)), name: CacheTaskManager.failedNotification, object: nil)
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: CacheTaskManager.progressNotification, object: nil)
        nc.removeObserver(self, name: CacheTaskManager.completedNotification, object: nil)
        nc.removeObserver(self, name: CacheTaskManager.failedNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

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
            CacheTaskManager.shared.start(book)
        }
    }

    @objc private func handleProgress(_ n: Notification) {
        guard let url = n.userInfo?["bookUrl"] as? String else { return }
        reloadVisibleRow(bookUrl: url)
    }

    @objc private func handleCompleted(_ n: Notification) {
        tableView.reloadData()
        shelfVC?.loadBooks()
    }

    @objc private func handleFailed(_ n: Notification) {
        tableView.reloadData()
    }

    private func reloadVisibleRow(bookUrl: String) {
        guard let idx = books.firstIndex(where: { $0.bookUrl == bookUrl }),
              idx + 1 < tableView.numberOfRows(inSection: 0) else { return }
        tableView.reloadRows(at: [IndexPath(row: idx + 1, section: 0)], with: .none)
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
        cell.accessoryView = nil
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
        let state = CacheTaskManager.shared.state(for: book.bookUrl)

        cell.textLabel?.text = book.name
        cell.backgroundColor = .white

        if let s = state {
            if s.isPaused {
                cell.detailTextLabel?.text = "已暂停 \(s.currentIndex)/\(s.total) 章"
                cell.textLabel?.textColor = .systemOrange
            } else {
                cell.detailTextLabel?.text = "缓存中 \(s.currentIndex)/\(s.total) 章"
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

        if cached > 0 {
            let btn = UIButton(type: .system)
            btn.setImage(UIImage(systemName: "trash"), for: .normal)
            btn.tintColor = .systemRed
            btn.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
            btn.tag = ip.row
            btn.addTarget(self, action: #selector(deleteTapped(_:)), for: .touchUpInside)
            cell.accessoryView = btn
        }

        return cell
    }

    func tableView(_: UITableView, didSelectRowAt ip: IndexPath) {
        guard ip.row > 0 else { return }
        let book = books[ip.row - 1]
        if CacheTaskManager.shared.isCaching(book.bookUrl) {
            CacheTaskManager.shared.togglePause(book.bookUrl)
            tableView.reloadData()
        } else {
            let cached = CacheManager.shared.cachedCount(book.bookUrl)
            let total = CacheManager.shared.cachedTotal(book.bookUrl)
            if total > 0 && cached >= total {
                clearCache(book)
            } else {
                CacheTaskManager.shared.start(book)
                tableView.reloadData()
            }
        }
    }

    func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt ip: IndexPath) -> UISwipeActionsConfiguration? {
        guard ip.row > 0 else { return nil }
        let book = books[ip.row - 1]
        if CacheTaskManager.shared.isCaching(book.bookUrl) { return nil }
        let cached = CacheManager.shared.cachedCount(book.bookUrl)
        guard cached > 0 else { return nil }
        let clear = UIContextualAction(style: .destructive, title: "清除") { [weak self] _, _, done in
            self?.clearCache(book)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [clear])
    }
}
