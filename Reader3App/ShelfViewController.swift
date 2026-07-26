import UIKit

class ShelfViewController: UIViewController {
    private var books: [Book] = []
    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()

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
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "搜索", style: .plain, target: self, action: #selector(showSearch))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "刷新", style: .plain, target: self, action: #selector(refreshBooks))
    }

    @objc private func showSearch() {
        let search = SearchViewController()
        search.onSelect = { [weak self] result in
            self?.addAndOpen(result)
        }
        present(UINavigationController(rootViewController: search), animated: true)
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
        cell.configure(with: books[ip.item])
        return cell
    }

    func collectionView(_: UICollectionView, didSelectItemAt ip: IndexPath) {
        openBook(books[ip.item])
    }
}

class BookCell: UICollectionViewCell {
    private let coverView = UIImageView()
    private let nameLabel = UILabel()
    private let authorLabel = UILabel()

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
        [coverView, nameLabel, authorLabel].forEach {
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
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(with book: Book) {
        nameLabel.text = book.name
        authorLabel.text = book.author
        if let url = book.coverImageURL {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let d = data { DispatchQueue.main.async { self?.coverView.image = UIImage(data: d) } }
            }.resume()
        }
    }
}
