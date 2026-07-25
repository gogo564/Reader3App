import UIKit

class SearchViewController: UIViewController {
    var onSelect: ((SearchResult) -> Void)?
    private var results: [SearchResult] = []
    private let searchBar = UISearchBar()
    private let tableView = UITableView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "搜索"
        view.backgroundColor = .systemBackground
        searchBar.placeholder = "搜索书名或作者"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        let stack = UIStackView(arrangedSubviews: [searchBar, tableView])
        stack.axis = .vertical
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissSelf))
        searchBar.becomeFirstResponder()
    }

    @objc private func dismissSelf() { dismiss(animated: true) }

    private func search(_ key: String) {
        Task {
            do {
                let r = try await NetworkService.shared.searchBook(key: key, searchType: "multi", concurrentCount: 24)
                await MainActor.run { results = r; tableView.reloadData() }
            } catch {}
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
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: ip)
        let r = results[ip.row]
        cell.textLabel?.text = r.name
        cell.detailTextLabel?.text = r.author
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt ip: IndexPath) {
        onSelect?(results[ip.row])
        dismiss(animated: true)
    }
}
