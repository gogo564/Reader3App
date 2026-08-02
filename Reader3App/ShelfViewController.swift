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
    private var cacheManageVC: CacheManageViewController?
    private var openingCells: [String: IndexPath] = [:]

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
                AppState.shared.clearDeleted(bookUrl: book.bookUrl)
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
                books = books.filter { !AppState.shared.isDeleted(bookUrl: $0.bookUrl) }
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
                    let cached = cached.filter { !AppState.shared.isDeleted(bookUrl: $0.bookUrl) }
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
                books = books.filter { !AppState.shared.isDeleted(bookUrl: $0.bookUrl) }
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
                    let cached = cached.filter { !AppState.shared.isDeleted(bookUrl: $0.bookUrl) }
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
            AppState.shared.markDeleted(bookUrl: book.bookUrl)
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

    private func endOpening(bookUrl: String) {
        guard let ip = openingCells.removeValue(forKey: bookUrl) else { return }
        if let cell = collectionView.cellForItem(at: ip) as? BookCell {
            cell.setLoading(false)
        }
    }

    private func openBook(_ book: Book) {
        crashLog("[openBook] name=\(book.name) idx=\(book.durChapterIndex ?? -1) pos=\(book.durChapterPos ?? -1) time=\(book.durChapterTime ?? -1)")
        let openingKey = book.bookUrl
        let readController = DZMReadController()
        readController.bookAuthor = book.author
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

        func tryOpen(currentBook: Book, hasSwitched: Bool) {
            Task {
                do {
                    let chapters = try await readController.chapterList!(currentBook.bookUrl)
                    readController.catalogChapters = chapters
                    let index = currentBook.durChapterIndex ?? 0
                    let rawContent = try await readController.chapterContent!(currentBook.bookUrl, index)
                    let content = DZMReadParser.contentTypesetting(content: rawContent)

                    readModel.bookID = currentBook.bookUrl
                    let recordModel = DZMReadRecordModel()
                    recordModel.bookID = currentBook.bookUrl
                    let chapterModel = DZMReadChapterModel()
                    chapterModel.bookID = currentBook.bookUrl
                    chapterModel.id = NSNumber(value: index)
                    chapterModel.name = currentBook.durChapterTitle ?? chapters[safe: index]?.title ?? "开始阅读"
                    chapterModel.content = content
                    chapterModel.priority = NSNumber(value: index)
                    if index > 0 { chapterModel.previousChapterID = NSNumber(value: index - 1) }
                    else { chapterModel.previousChapterID = DZM_READ_NO_MORE_CHAPTER }
                    if index < chapters.count - 1 { chapterModel.nextChapterID = NSNumber(value: index + 1) }
                    else { chapterModel.nextChapterID = DZM_READ_NO_MORE_CHAPTER }
                    chapterModel.updateFont()
                    recordModel.chapterModel = chapterModel
                    if let pos = currentBook.durChapterPos, pos > 0 {
                        recordModel.modify(chapterID: chapterModel.id, location: pos)
                    }
                    readModel.recordModel = recordModel

                    readModel.chapterListModels.removeAll()
                    for (i, ch) in chapters.enumerated() {
                        let lm = DZMReadChapterListModel()
                        lm.id = NSNumber(value: i)
                        lm.name = ch.title
                        lm.bookID = currentBook.bookUrl
                        readModel.chapterListModels.append(lm)
                    }

                    await MainActor.run {
                        readController.readModel = readModel
                        self.endOpening(bookUrl: openingKey)
                        navigationController?.pushViewController(readController, animated: true)
                    }

                    prefetchNextChapters(book: currentBook, from: index + 1)
                } catch {
                    if !hasSwitched {
                        if let newBook = try? await NetworkService.shared.autoSwitchSource(for: currentBook) {
                            var cached = CacheManager.shared.getCachedBookshelf() ?? []
                            if let idx = cached.firstIndex(where: { $0.name == currentBook.name }) {
                                cached[idx] = newBook
                                CacheManager.shared.cacheBookshelf(cached)
                            }
                            Task { try? await NetworkService.shared.saveBook(newBook) }
                            Task { try? await NetworkService.shared.deleteBook(bookUrl: currentBook.bookUrl) }
                            await MainActor.run { self.books = cached; self.collectionView.reloadData() }
                            tryOpen(currentBook: newBook, hasSwitched: true)
                            return
                        }
                    }
                    await MainActor.run {
                        if let chapters = self.chapterListCache(bookUrl: currentBook.bookUrl),
                           let rawContent = self.cachedContent(bookUrl: currentBook.bookUrl, index: currentBook.durChapterIndex ?? 0) {
                            let index = currentBook.durChapterIndex ?? 0
                            readController.catalogChapters = chapters
                            readModel.chapterListModels.removeAll()
                            for (i, ch) in chapters.enumerated() {
                                let lm = DZMReadChapterListModel()
                                lm.id = NSNumber(value: i)
                                lm.name = ch.title
                                lm.bookID = currentBook.bookUrl
                                readModel.chapterListModels.append(lm)
                            }
                            let cm = DZMReadChapterModel()
                            cm.bookID = currentBook.bookUrl
                            cm.id = NSNumber(value: index)
                            cm.name = currentBook.durChapterTitle ?? chapters.first?.title ?? "开始阅读"
                            cm.content = DZMReadParser.contentTypesetting(content: rawContent)
                            cm.priority = NSNumber(value: index)
                            if index > 0 { cm.previousChapterID = NSNumber(value: index - 1) }
                            else { cm.previousChapterID = DZM_READ_NO_MORE_CHAPTER }
                            if index < chapters.count - 1 { cm.nextChapterID = NSNumber(value: index + 1) }
                            else { cm.nextChapterID = DZM_READ_NO_MORE_CHAPTER }
                            cm.updateFont()
                            let rm = DZMReadRecordModel()
                            rm.bookID = currentBook.bookUrl
                            rm.chapterModel = cm
                            if let pos = currentBook.durChapterPos, pos > 0 {
                                rm.modify(chapterID: cm.id, location: pos)
                            }
                            readModel.recordModel = rm
                            readController.readModel = readModel
                            self.endOpening(bookUrl: openingKey)
                            navigationController?.pushViewController(readController, animated: true)
                            return
                        }
                        if let cached = self.cachedContent(bookUrl: currentBook.bookUrl, index: currentBook.durChapterIndex ?? 0) {
                            readModel.chapterListModels.removeAll()
                            let lm = DZMReadChapterListModel()
                            lm.id = NSNumber(value: currentBook.durChapterIndex ?? 0)
                            lm.name = currentBook.durChapterTitle ?? "开始阅读"
                            lm.bookID = currentBook.bookUrl
                            readModel.chapterListModels.append(lm)
                            let cm = DZMReadChapterModel()
                            cm.bookID = currentBook.bookUrl
                            cm.id = NSNumber(value: currentBook.durChapterIndex ?? 0)
                            cm.name = currentBook.durChapterTitle ?? "开始阅读"
                            cm.content = DZMReadParser.contentTypesetting(content: cached)
                            cm.priority = NSNumber(value: currentBook.durChapterIndex ?? 0)
                            cm.previousChapterID = DZM_READ_NO_MORE_CHAPTER
                            cm.nextChapterID = DZM_READ_NO_MORE_CHAPTER
                            cm.updateFont()
                            let rm = DZMReadRecordModel()
                            rm.bookID = currentBook.bookUrl
                            rm.chapterModel = cm
                            if let pos = currentBook.durChapterPos, pos > 0 {
                                rm.modify(chapterID: cm.id, location: pos)
                            }
                            readModel.recordModel = rm
                            readController.readModel = readModel
                            self.endOpening(bookUrl: openingKey)
                            navigationController?.pushViewController(readController, animated: true)
                            return
                        }
                        self.endOpening(bookUrl: openingKey)
                        let msg: String
                        if !NetworkMonitor.shared.isConnected {
                            msg = "当前无网络连接，请联网后重试"
                        } else {
                            msg = "加载失败，请检查网络后重试"
                        }
                        let alert = UIAlertController(title: "加载失败", message: msg, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }

        tryOpen(currentBook: book, hasSwitched: false)
    }

    private func prefetchNextChapters(book: Book, from index: Int) {
        guard NetworkMonitor.shared.isConnected else { return }
        guard let chapters = CacheManager.shared.getCachedChapters(bookUrl: book.bookUrl) else { return }
        let end = min(index + 5, chapters.count)
        guard index < end else { return }
        Task {
            for i in index..<end {
                if CacheManager.shared.isChapterCached(bookUrl: book.bookUrl, index: i) { continue }
                guard NetworkMonitor.shared.isConnected else { break }
                if let c = try? await NetworkService.shared.getBookContent(bookUrl: book.bookUrl, index: i) {
                    CacheManager.shared.cacheChapter(bookUrl: book.bookUrl, index: i, content: c)
                } else { break }
            }
        }
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
        let book = filteredBooks[ip.item]
        guard openingCells[book.bookUrl] == nil else { return }
        openingCells[book.bookUrl] = ip
        (collectionView.cellForItem(at: ip) as? BookCell)?.setLoading(true)
        openBook(book)
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
        setLoading(false)
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

    private var loadingView: UIActivityIndicatorView?

    func setLoading(_ isLoading: Bool) {
        if isLoading {
            if loadingView == nil {
                let v = UIActivityIndicatorView(style: .medium)
                v.color = .white
                v.backgroundColor = UIColor.black.withAlphaComponent(0.35)
                v.layer.cornerRadius = 6
                contentView.addSubview(v)
                v.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    v.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                    v.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                    v.widthAnchor.constraint(equalToConstant: 44),
                    v.heightAnchor.constraint(equalToConstant: 44),
                ])
                loadingView = v
            }
            loadingView?.startAnimating()
            loadingView?.isHidden = false
        } else {
            loadingView?.stopAnimating()
            loadingView?.removeFromSuperview()
            loadingView = nil
        }
    }
}

