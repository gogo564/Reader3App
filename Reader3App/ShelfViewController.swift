import UIKit

class ShelfViewController: UIViewController {
    private var books: [Book] = []
    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()
    private var isEditingMode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "书架"
        view.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        setupCollectionView()
        setupNavigationBar()
        loadBooks()
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
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
            let refreshBtn = UIBarButtonItem(title: "刷新", style: .plain, target: self, action: #selector(refreshBooks))
            navigationItem.rightBarButtonItems = [refreshBtn, editBtn]
        }
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
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .done, target: self, action: #selector(dismissLog))
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func dismissLog() {
        dismiss(animated: true)
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
                await MainActor.run { openBook(book) }
            } catch {}
        }
    }

    private func loadBooks() {
        Task {
            do {
                let books = try await NetworkService.shared.getBookshelf()
                await MainActor.run {
                    self.books = books
                    self.collectionView.reloadData()
                }
            } catch {}
        }
    }

    @objc private func refreshBooks() {
        Task {
            do {
                let books = try await NetworkService.shared.getBookshelf(refresh: true)
                await MainActor.run {
                    self.books = books
                    self.collectionView.reloadData()
                    self.refreshControl.endRefreshing()
                }
            } catch {
                await MainActor.run { self.refreshControl.endRefreshing() }
            }
        }
    }

    private func deleteBook(_ book: Book) {
        let alert = UIAlertController(title: "删除书籍", message: "确定删除「\(book.name)」吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            Task {
                do {
                    try await NetworkService.shared.deleteBook(bookUrl: book.bookUrl)
                    await MainActor.run {
                        self.books.removeAll { $0.bookUrl == book.bookUrl }
                        self.collectionView.reloadData()
                    }
                } catch {
                    await MainActor.run {
                        let errAlert = UIAlertController(title: "删除失败", message: error.localizedDescription, preferredStyle: .alert)
                        errAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(errAlert, animated: true)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func openBook(_ book: Book) {
        let readController = DZMReadController()
        let readModel = DZMReadModel()
        readModel.bookID = book.bookUrl
        readModel.bookName = book.name

        readController.chapterList = { bookUrl in
            try await NetworkService.shared.getChapterList(bookUrl: bookUrl)
        }
        readController.chapterContent = { bookUrl, index in
            try await NetworkService.shared.getBookContent(bookUrl: bookUrl, index: index)
        }

        Task {
            do {
                let chapters = try await readController.chapterList!(book.bookUrl)
                readController.catalogChapters = chapters
                let index = book.durChapterIndex ?? 0
                let rawContent = try await readController.chapterContent!(book.bookUrl, index)
                let content = DZMReadParser.contentTypesetting(content: rawContent)

                let recordModel = DZMReadRecordModel()
                recordModel.bookID = book.bookUrl
                let chapterModel = DZMReadChapterModel()
                chapterModel.bookID = book.bookUrl
                chapterModel.id = NSNumber(value: index)
                chapterModel.name = book.durChapterTitle ?? chapters[safe: index]?.title ?? "开始阅读"
                chapterModel.content = content
                chapterModel.priority = NSNumber(value: index)
                if index > 0 { chapterModel.previousChapterID = NSNumber(value: index - 1) }
                else { chapterModel.previousChapterID = DZM_READ_NO_MORE_CHAPTER }
                if index < chapters.count - 1 { chapterModel.nextChapterID = NSNumber(value: index + 1) }
                else { chapterModel.nextChapterID = DZM_READ_NO_MORE_CHAPTER }
                chapterModel.updateFont()
                recordModel.chapterModel = chapterModel
                readModel.recordModel = recordModel

                for (i, ch) in chapters.enumerated() {
                    let lm = DZMReadChapterListModel()
                    lm.id = NSNumber(value: i)
                    lm.name = ch.title
                    lm.bookID = book.bookUrl
                    readModel.chapterListModels.append(lm)
                }

                await MainActor.run {
                    readController.readModel = readModel
                    navigationController?.pushViewController(readController, animated: true)
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(title: "加载失败", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

extension ShelfViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int { books.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip) as! BookCell
        cell.configure(with: books[ip.item], showDelete: isEditingMode)
        cell.onDelete = { [weak self] in
            self?.deleteBook(self!.books[ip.item])
        }
        return cell
    }

    func collectionView(_: UICollectionView, didSelectItemAt ip: IndexPath) {
        guard !isEditingMode else { return }
        openBook(books[ip.item])
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
        authorLabel.font = .systemFont(ofSize: 10)
        authorLabel.textColor = .secondaryLabel
        authorLabel.textAlignment = .center
        authorLabel.numberOfLines = 1
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
        if let url = book.coverImageURL {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let d = data { DispatchQueue.main.async { self?.coverView.image = UIImage(data: d) } }
            }.resume()
        }
    }
}
