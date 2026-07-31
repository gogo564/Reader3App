import UIKit

class ShelfViewController: UIViewController {
    private var books: [Book] = []
    private var filteredBooks: [Book] { books }
    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()
    private var isEditingMode = false
    private let networkBar = UIView()
    private let networkLabel = UILabel()
    private let networkDot = UIView()
    private let pendingLabel = UILabel()
    private var cacheManageVC: CacheManageViewController?
    private var openingBookURL: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "书架"
        view.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        setupNetworkBar()
        setupCollectionView()
        setupNavigationBar()
        updateNetworkBar()
        loadBooks()
        NotificationCenter.default.addObserver(self, selector: #selector(loadBooks), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(networkChanged), name: .networkStatusChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        openingBookURL = nil
        loadBooks()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func networkChanged() {
        DispatchQueue.main.async { self.updateNetworkBar() }
    }

    private func updateNetworkBar() {
        let online = NetworkMonitor.shared.isConnected
        networkDot.backgroundColor = online ? .systemGreen : .systemRed
        networkDot.layer.cornerRadius = 4
        networkDot.clipsToBounds = true
        networkLabel.text = online ? "在线" : "离线"
        networkLabel.textColor = online ? .darkText : .systemRed
        let pending = SyncQueue.shared.pendingCount
        if pending > 0 {
            pendingLabel.text = "待同步 \(pending)"
            pendingLabel.textColor = .systemOrange
        } else {
            pendingLabel.text = ""
        }
        networkBar.backgroundColor = online
            ? UIColor(white: 1, alpha: 0.9)
            : UIColor(red: 1, green: 0.95, blue: 0.95, alpha: 0.95)
        networkBar.isHidden = false
    }

    private func setupNetworkBar() {
        networkBar.isHidden = false
        networkBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(networkBar)

        networkDot.translatesAutoresizingMaskIntoConstraints = false
        networkDot.layer.cornerRadius = 4
        networkBar.addSubview(networkDot)

        networkLabel.font = .systemFont(ofSize: 12)
        networkLabel.translatesAutoresizingMaskIntoConstraints = false
        networkBar.addSubview(networkLabel)

        pendingLabel.font = .systemFont(ofSize: 11)
        pendingLabel.translatesAutoresizingMaskIntoConstraints = false
        networkBar.addSubview(pendingLabel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(showCacheManage))
        networkBar.addGestureRecognizer(tap)

        NSLayoutConstraint.activate([
            networkBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            networkBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            networkBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            networkBar.heightAnchor.constraint(equalToConstant: 28),

            networkDot.centerYAnchor.constraint(equalTo: networkBar.centerYAnchor),
            networkDot.leadingAnchor.constraint(equalTo: networkBar.leadingAnchor, constant: 12),
            networkDot.widthAnchor.constraint(equalToConstant: 8),
            networkDot.heightAnchor.constraint(equalToConstant: 8),

            networkLabel.centerYAnchor.constraint(equalTo: networkBar.centerYAnchor),
            networkLabel.leadingAnchor.constraint(equalTo: networkDot.trailingAnchor, constant: 6),

            pendingLabel.centerYAnchor.constraint(equalTo: networkBar.centerYAnchor),
            pendingLabel.trailingAnchor.constraint(equalTo: networkBar.trailingAnchor, constant: -12),
        ])
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: (view.bounds.width - 48) / 3, height: 200)
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.register(BookCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshBooks), for: .valueChanged)
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: networkBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(title: "搜索", style: .plain, target: self, action: #selector(showSearch)),
            UIBarButtonItem(title: "日志", style: .plain, target: self, action: #selector(showCrashLog)),
        ]
        updateRightBarButton()
    }

    private func updateRightBarButton() {
        if isEditingMode {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(toggleEdit))
        } else {
            let editBtn = UIBarButtonItem(title: "编辑", style: .plain, target: self, action: #selector(toggleEdit))
            let cacheBtn = UIBarButtonItem(title: "缓存", style: .plain, target: self, action: #selector(showCacheManage))
            navigationItem.rightBarButtonItems = [editBtn, cacheBtn]
        }
    }

    @objc private func showCacheManage() {
        let vc = CacheManageViewController(books: books, shelfVC: self)
        cacheManageVC = vc
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    @objc private func toggleEdit() {
        isEditingMode.toggle()
        updateRightBarButton()
        collectionView.reloadData()
    }

    @objc private func showSearch() {
        let search = SearchViewController()
        search.onSelect = { [weak self] result in
            self?.addAndOpen(result)
        }
        present(UINavigationController(rootViewController: search), animated: true)
    }

    @objc private func showCrashLog() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("crash.log")
        let text: String
        if let u = url, let data = try? Data(contentsOf: u), let s = String(data: data, encoding: .utf8), !s.isEmpty {
            text = s
        } else {
            text = "暂无崩溃日志"
        }
        let vc = UIViewController()
        let tv = UITextView(frame: .zero)
        tv.text = text
        tv.isEditable = false
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        vc.view.addSubview(tv)
        tv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: vc.view.topAnchor),
            tv.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            tv.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
        ])
        vc.title = "崩溃日志"
        vc.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "清除", style: .plain, target: self, action: #selector(clearCrashLog(sender:)))
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .done, target: self, action: #selector(dismissLog))
        logNav = UINavigationController(rootViewController: vc)
        logNav!.modalPresentationStyle = .fullScreen
        present(logNav!, animated: true)
    }

    private var logNav: UINavigationController?

    @objc private func clearCrashLog(sender: UIBarButtonItem) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("crash.log")
        guard let u = url else { return }
        do {
            try "".write(to: u, atomically: true, encoding: .utf8)
        } catch {}
        if let vc = logNav?.viewControllers.first as? UIViewController,
           let tv = vc.view.subviews.first as? UITextView {
            tv.text = "暂无崩溃日志"
        }
    }

    @objc private func dismissLog() {
        dismiss(animated: true)
        logNav = nil
    }

    private func addAndOpen(_ result: SearchResult) {
        let book = Book(bookUrl: result.bookUrl, name: result.name,
                        author: result.author, coverUrl: result.coverUrl,
                        origin: result.origin, originName: result.originName,
                        intro: result.intro,
                        latestChapterTitle: result.latestChapterTitle,
                        type: result.type, tocUrl: result.tocUrl)
        Task {
            do {
                _ = try await NetworkService.shared.saveBook(book)
                var cached = CacheManager.shared.getCachedBookshelf() ?? []
                if !cached.contains(where: { $0.bookUrl == book.bookUrl }) {
                    cached.append(book)
                    CacheManager.shared.cacheBookshelf(cached)
                }
                await MainActor.run { openBook(book) }
            } catch {}
        }
    }

    @objc func loadBooks() {
        Task {
            do {
                var books = try await NetworkService.shared.getBookshelf()
                let cached = CacheManager.shared.getCachedBookshelf() ?? []
                books = books.map { server in
                    guard let c = cached.first(where: { $0.bookUrl == server.bookUrl }),
                          let localTime = c.durChapterTime else { return server }
                    if (server.durChapterTime ?? 0) < localTime {
                        return server.withProgress(index: c.durChapterIndex ?? 0, title: c.durChapterTitle, time: localTime, pos: c.durChapterPos)
                    }
                    return server
                }
                CacheManager.shared.cacheBookshelf(books)
                await AppState.shared.syncPendingDeletes()
                await MainActor.run {
                    self.books = books
                    self.cacheManageVC?.updateBooks(books)
                    self.collectionView.reloadData()
                    self.updateNetworkBar()
                }
            } catch {
                if let cached = CacheManager.shared.getCachedBookshelf() {
                    await MainActor.run {
                        self.books = cached
                        self.cacheManageVC?.updateBooks(cached)
                        self.collectionView.reloadData()
                    }
                }
                await MainActor.run { self.updateNetworkBar() }
            }
        }
    }

    @objc private func refreshBooks() {
        Task {
            do {
                var books = try await NetworkService.shared.getBookshelf(refresh: false)
                let cached = CacheManager.shared.getCachedBookshelf() ?? []
                books = books.map { server in
                    guard let c = cached.first(where: { $0.bookUrl == server.bookUrl }),
                          let localTime = c.durChapterTime else { return server }
                    if (server.durChapterTime ?? 0) < localTime {
                        return server.withProgress(index: c.durChapterIndex ?? 0, title: c.durChapterTitle, time: localTime, pos: c.durChapterPos)
                    }
                    return server
                }
                CacheManager.shared.cacheBookshelf(books)
                await AppState.shared.syncPendingDeletes()
                await MainActor.run {
                    self.books = books
                    self.cacheManageVC?.updateBooks(books)
                    self.collectionView.reloadData()
                    self.refreshControl.endRefreshing()
                    self.updateNetworkBar()
                }
            } catch {
                if let cached = CacheManager.shared.getCachedBookshelf() {
                    await MainActor.run {
                        self.books = cached
                        self.cacheManageVC?.updateBooks(cached)
                        self.collectionView.reloadData()
                    }
                }
                await MainActor.run { self.refreshControl.endRefreshing() }
            }
        }
    }

    private func deleteBook(_ book: Book) {
        let alert = UIAlertController(title: "删除书籍", message: "确定删除「\(book.name)」吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.books.removeAll { $0.bookUrl == book.bookUrl }
            self.collectionView.reloadData()
            CacheManager.shared.clearCache(bookUrl: book.bookUrl)
            Task {
                do {
                    try await NetworkService.shared.deleteBook(bookUrl: book.bookUrl)
                } catch {
                    AppState.shared.addPendingDelete(bookUrl: book.bookUrl)
                }
            }
        })
        present(alert, animated: true)
    }

    private func cachedContent(bookUrl: String, index: Int) -> String? {
        if CacheManager.shared.isChapterCached(bookUrl: bookUrl, index: index) {
            return CacheManager.shared.getCachedChapter(bookUrl: bookUrl, index: index)
        }
        return nil
    }

    private func openBook(_ book: Book) {
        guard openingBookURL != book.bookUrl else { return }
        openingBookURL = book.bookUrl

        let readController = DZMReadController()
        readController.bookAuthor = book.author
        readController.book = book
        readController.bookInitialIndex = book.durChapterIndex ?? 0
        readController.bookInitialTitle = book.durChapterTitle
        readController.bookInitialPos = book.durChapterPos ?? 0
        let readModel = DZMReadModel()
        readModel.bookID = book.bookUrl
        readModel.bookName = book.name
        readModel.loadMarks()

        readController.chapterList = { [weak self] bookUrl in
            if let cached = self?.chapterListCache(bookUrl: bookUrl) { return cached }
            guard NetworkMonitor.shared.isConnected else {
                throw NSError(domain: "Offline", code: -1, userInfo: nil)
            }
            let chapters = try await NetworkService.shared.getChapterList(bookUrl: bookUrl)
            CacheManager.shared.cacheChapters(bookUrl: bookUrl, chapters: chapters)
            return chapters
        }
        readController.chapterContent = { [weak self] bookUrl, index in
            if let c = self?.cachedContent(bookUrl: bookUrl, index: index) { return c }
            guard NetworkMonitor.shared.isConnected else {
                throw NSError(domain: "Offline", code: -1, userInfo: nil)
            }
            return try await NetworkService.shared.getBookContent(bookUrl: bookUrl, index: index)
        }

        readController.readModel = readModel
        navigationController?.pushViewController(readController, animated: false)
    }

    private func chapterListCache(bookUrl: String) -> [Chapter]? {
        guard CacheManager.shared.cachedCount(bookUrl) > 0 else { return nil }
        return CacheManager.shared.getCachedChapters(bookUrl: bookUrl)
    }
}

extension ShelfViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int { filteredBooks.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip) as! BookCell
        let book = filteredBooks[ip.item]
        cell.configure(with: book, showDelete: isEditingMode)
        cell.onDelete = { [weak self] in
            self?.deleteBook(book)
        }
        return cell
    }

    func collectionView(_: UICollectionView, didSelectItemAt ip: IndexPath) {
        guard !isEditingMode else { return }
        openBook(filteredBooks[ip.item])
    }
}

class BookCell: UICollectionViewCell {
    private let coverView = UIImageView()
    private let nameLabel = UILabel()
    private let authorLabel = UILabel()
    private let progressLabel = UILabel()
    private let deleteButton = UIButton(type: .system)
    var onDelete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 6
        contentView.clipsToBounds = true
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.backgroundColor = UIColor(white: 0.9, alpha: 1)
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.6
        authorLabel.font = .systemFont(ofSize: 10)
        authorLabel.textColor = .secondaryLabel
        authorLabel.textAlignment = .center
        authorLabel.numberOfLines = 1
        authorLabel.adjustsFontSizeToFitWidth = true
        authorLabel.minimumScaleFactor = 0.6
        progressLabel.font = .systemFont(ofSize: 9)
        progressLabel.textColor = UIColor(red: 0.58, green: 0.58, blue: 0.58, alpha: 1)
        progressLabel.textAlignment = .center
        progressLabel.numberOfLines = 2
        [coverView, nameLabel, authorLabel, progressLabel, deleteButton].forEach {
            contentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            coverView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            coverView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            coverView.widthAnchor.constraint(equalToConstant: 80),
            coverView.heightAnchor.constraint(equalToConstant: 110),
            nameLabel.topAnchor.constraint(equalTo: coverView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            authorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            authorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            progressLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 1),
            progressLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            progressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
        ])
        deleteButton.setTitle("✕", for: .normal)
        deleteButton.backgroundColor = UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.layer.cornerRadius = 12
        deleteButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        deleteButton.isHidden = true
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        NSLayoutConstraint.activate([
            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -4),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 4),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    required init?(coder: NSCoder) { nil }

    @objc private func didTapDelete() { onDelete?() }

    func configure(with book: Book, showDelete: Bool = false) {
        nameLabel.text = book.name
        authorLabel.text = book.author
        deleteButton.isHidden = !showDelete
        if let t = book.durChapterTitle, let i = book.durChapterIndex {
            progressLabel.text = "已读至\(i+1)章\n\(t)"
        } else {
            progressLabel.text = "未阅读"
        }
        if let cached = CacheManager.shared.getCachedCover(bookUrl: book.bookUrl) {
            coverView.image = cached
        } else if let url = book.coverImageURL {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let d = data {
                    CacheManager.shared.cacheCover(bookUrl: book.bookUrl, imageData: d)
                    DispatchQueue.main.async { self?.coverView.image = UIImage(data: d) }
                }
            }.resume()
        }
    }
}
