import UIKit

class SourcePickerViewController: UIViewController {
    private let tableView = UITableView()
    private var results: [SearchResult] = []
    private let onSelect: (SearchResult) -> Void
    private let titleLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    init(onSelect: @escaping (SearchResult) -> Void) {
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

        titleLabel.text = "搜索中..."
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(loadingIndicator)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cancelButton)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableView)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.65),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            loadingIndicator.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            loadingIndicator.trailingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: -6),

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
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    func addResult(_ r: SearchResult) {
        results.append(r)
        titleLabel.text = "选择书源（共\(results.count)个）"
        loadingIndicator.stopAnimating()
        tableView.reloadData()
    }
}

extension SourcePickerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { results.count }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let id = "sub"
        var cell = tv.dequeueReusableCell(withIdentifier: id)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: id)
        }
        let r = results[ip.row]
        cell!.textLabel?.text = r.originName ?? "未知源"
        cell!.textLabel?.font = .systemFont(ofSize: 15)
        cell!.textLabel?.textColor = .label
        cell!.detailTextLabel?.text = r.latestChapterTitle ?? ""
        cell!.detailTextLabel?.font = .systemFont(ofSize: 12)
        cell!.detailTextLabel?.textColor = .secondaryLabel
        cell!.accessoryType = .disclosureIndicator
        cell!.selectionStyle = .default
        return cell!
    }

    func tableView(_: UITableView, didSelectRowAt ip: IndexPath) {
        let result = results[ip.row]
        dismiss(animated: true) { [weak self] in
            self?.onSelect(result)
        }
    }
}

extension SourcePickerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view == view
    }
}
