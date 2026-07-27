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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
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
        if books.isEmpty {
            cell.textLabel?.text = "暂无书籍"
            cell.textLabel?.textColor = .secondaryLabel
            cell.textLabel?.textAlignment = .center
            cell.selectionStyle = .none
            cell.backgroundColor = .white
            return cell
        }
        if ip.row == 0 {
            cell.textLabel?.text = SyncQueue.shared.pendingCount > 0
                ? "同步队列: \(SyncQueue.shared.pendingCount) 个待同步操作 ⏳"
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
        var detail = "已缓存 \(cached) 章"
        if total > 0 {
            detail += " / 共 \(total) 章"
            if cached >= total {
                detail += " ✅"
            }
        }
        cell.textLabel?.text = book.name
        cell.detailTextLabel?.text = detail
        cell.backgroundColor = .white
        return cell
    }
}
