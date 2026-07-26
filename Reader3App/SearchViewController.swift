import UIKit

class SearchViewController: UIViewController {
    var onSelect: ((SearchResult) -> Void)?
    private var results: [SearchResult] = []
    private let searchBar = UISearchBar()
    private let tableView = UITableView()
    private let emptyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "搜索"
        view.backgroundColor = .systemBackground
        searchBar.placeholder = "搜索书名或作者"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 80
        tableView.tableFooterView = UIView()

        emptyLabel.text = "输入关键词搜索书籍"
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.isHidden = false

        let stack = UIStackView(arrangedSubviews: [searchBar, tableView, emptyLabel])
        stack.axis = .vertical
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyLabel.heightAnchor.constraint(equalToConstant: 200),
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissSelf))
        searchBar.becomeFirstResponder()
    }

    @objc private func dismissSelf() { dismiss(animated: true) }

    private func search(_ key: String) {
        Task {
            do {
                let r = try await NetworkService.shared.searchBook(key: key, searchType: "multi", concurrentCount: 24)
                await MainActor.run {
                    results = r
                    tableView.reloadData()
                    emptyLabel.isHidden = !r.isEmpty
                    emptyLabel.text = r.isEmpty ? "未找到相关书籍" : ""
                }
            } catch {
                await MainActor.run {
                    emptyLabel.isHidden = false
                    emptyLabel.text = "搜索失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ bar: UISearchBar) {
        guard let text = bar.text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return }
        search(text)
        bar.resignFirstResponder()
    }
}

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { results.count }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: ip) as! SearchResultCell
        cell.configure(with: results[ip.row])
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt ip: IndexPath) {
        onSelect?(results[ip.row])
        dismiss(animated: true)
    }
}

class SearchResultCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let authorLabel = UILabel()
    private let originLabel = UILabel()
    private let chapterLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        nameLabel.font = .boldSystemFont(ofSize: 15)
        authorLabel.font = .systemFont(ofSize: 12)
        authorLabel.textColor = .secondaryLabel
        originLabel.font = .systemFont(ofSize: 11)
        originLabel.textColor = .tertiaryLabel
        chapterLabel.font = .systemFont(ofSize: 11)
        chapterLabel.textColor = .tertiaryLabel
        chapterLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [nameLabel, authorLabel, originLabel, chapterLabel])
        stack.axis = .vertical
        stack.spacing = 2
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) { nil }

    func configure(with r: SearchResult) {
        nameLabel.text = r.name
        authorLabel.text = r.author.map { "作者: \($0)" }
        originLabel.text = r.originName.map { "来源: \($0)" }
        chapterLabel.text = r.latestChapterTitle.map { "最新: \($0)" }
    }
}
