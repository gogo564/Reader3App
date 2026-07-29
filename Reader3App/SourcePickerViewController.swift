import UIKit

private struct SourceItem {
    let source: BookSource
    var status: SourceStatus
    var elapsed: TimeInterval
}

private enum SourceStatus {
    case searching, found, notFound
    var order: Int {
        switch self {
        case .found: return 0
        case .searching: return 1
        case .notFound: return 2
        }
    }
}

class SourcePickerViewController: UIViewController {
    private let tableView = UITableView()
    private var items: [SourceItem]
    private let bookName: String
    private let author: String?
    private let onSelect: (BookSource) -> Void

    init(sources: [BookSource], bookName: String, author: String?, onSelect: @escaping (BookSource) -> Void) {
        self.items = sources.map { SourceItem(source: $0, status: .searching, elapsed: 0) }
        self.bookName = bookName
        self.author = author
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.4)

        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let titleLabel = UILabel()
        titleLabel.text = "选择书源"
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cancelButton)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.65),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            cancelButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        tap.delegate = self
        view.addGestureRecognizer(tap)

        startSearch()
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    private func startSearch() {
        Task {
            await withTaskGroup(of: (Int, SourceStatus, TimeInterval).self) { group in
                for (i, item) in items.enumerated() {
                    guard let url = item.source.bookSourceUrl, !url.isEmpty else {
                        items[i].status = .notFound
                        continue
                    }
                    group.addTask {
                        let t0 = CFAbsoluteTimeGetCurrent()
                        guard let results = try? await NetworkService.shared.searchOnSource(bookName: self.bookName, sourceUrl: url) else {
                            return (i, .notFound, 0)
                        }
                        let elapsed = CFAbsoluteTimeGetCurrent() - t0
                        for r in results {
                            guard r.name == self.bookName else { continue }
                            if let a = self.author, !a.isEmpty, r.author != a { continue }
                            return (i, .found, elapsed)
                        }
                        return (i, .notFound, elapsed)
                    }
                }
                for await (idx, status, elapsed) in group {
                    guard idx < self.items.count else { continue }
                    self.items[idx].status = status
                    self.items[idx].elapsed = elapsed
                    self.reloadAndSort()
                }
            }
            if items.allSatisfy({ $0.status != .searching }) && !items.contains(where: { $0.status == .found }) {
                let alert = UIAlertController(title: "提示", message: "所有书源均未找到本书", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
                    self?.dismiss(animated: true)
                })
                present(alert, animated: true)
            }
        }
    }

    private func reloadAndSort() {
        items.sort { a, b in
            if a.status.order != b.status.order { return a.status.order < b.status.order }
            return a.elapsed < b.elapsed
        }
        tableView.reloadData()
    }
}

extension SourcePickerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { items.count }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: ip)
        let item = items[ip.row]
        cell.textLabel?.text = item.source.bookSourceName ?? "未知源"
        cell.textLabel?.font = .systemFont(ofSize: 15)
        switch item.status {
        case .searching:
            cell.accessoryType = .none
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            cell.accessoryView = spinner
            cell.textLabel?.textColor = .secondaryLabel
            cell.selectionStyle = .none
        case .found:
            cell.accessoryView = nil
            cell.accessoryType = .checkmark
            cell.tintColor = .systemGreen
            cell.textLabel?.textColor = .label
            cell.selectionStyle = .default
        case .notFound:
            cell.accessoryView = nil
            cell.accessoryType = .none
            cell.textLabel?.textColor = .tertiaryLabel
            cell.selectionStyle = .none
        }
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt ip: IndexPath) {
        let item = items[ip.row]
        guard item.status == .found else { return }
        dismiss(animated: true) { [weak self] in
            self?.onSelect(item.source)
        }
    }
}

extension SourcePickerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view == view
    }
}
