import UIKit

class SetupViewController: UIViewController {
    private let urlField = UITextField()
    private let connectButton = UIButton(type: .system)
    private let loading = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        setupUI()

        if let saved = UserDefaults.standard.string(forKey: "serverURL"), !saved.isEmpty {
            urlField.text = saved
            connect()
        }
    }

    private func setupUI() {
        let icon = UILabel()
        icon.text = "📖"
        icon.font = .systemFont(ofSize: 64)
        icon.textAlignment = .center
        view.addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Reader"
        title.font = .boldSystemFont(ofSize: 28)
        title.textAlignment = .center
        view.addSubview(title)
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "清风不识字，何故乱翻书"
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        view.addSubview(subtitle)
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        urlField.placeholder = "服务器地址 如: 192.168.1.100:8080"
        urlField.borderStyle = .roundedRect
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.keyboardType = .URL
        urlField.returnKeyType = .go
        urlField.delegate = self
        view.addSubview(urlField)
        urlField.translatesAutoresizingMaskIntoConstraints = false

        connectButton.setTitle("连接服务器", for: .normal)
        connectButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        connectButton.backgroundColor = UIColor(red: 253/255, green: 85/255, blue: 103/255, alpha: 1)
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.layer.cornerRadius = 8
        connectButton.addTarget(self, action: #selector(connect), for: .touchUpInside)
        view.addSubview(connectButton)
        connectButton.translatesAutoresizingMaskIntoConstraints = false

        loading.hidesWhenStopped = true
        view.addSubview(loading)
        loading.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        view.addSubview(errorLabel)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        setupOfflineButton()
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            icon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 8),
            subtitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            urlField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            urlField.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 40),
            urlField.widthAnchor.constraint(equalToConstant: 300),
            urlField.heightAnchor.constraint(equalToConstant: 44),
            connectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            connectButton.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 20),
            connectButton.widthAnchor.constraint(equalToConstant: 200),
            connectButton.heightAnchor.constraint(equalToConstant: 44),
            loading.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loading.topAnchor.constraint(equalTo: connectButton.bottomAnchor, constant: 16),
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: loading.bottomAnchor, constant: 8),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    private let offlineButton = UIButton(type: .system)

    @objc private func connect() {
        guard var text = urlField.text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else {
            errorLabel.text = "请输入服务器地址"
            return
        }
        if !text.hasPrefix("http://") && !text.hasPrefix("https://") {
            text = "http://" + text
        }
        errorLabel.text = nil
        loading.startAnimating()
        connectButton.isEnabled = false
        offlineButton.isHidden = true

        Task {
            do {
                try await NetworkService.shared.testConnection(serverURL: text)
                await MainActor.run {
                    UserDefaults.standard.set(text, forKey: "serverURL")
                    AppState.shared.serverURL = text
                    AppState.shared.isConnected = true
                    loading.stopAnimating()
                    let shelf = ShelfViewController()
                    navigationController?.setViewControllers([shelf], animated: true)
                }
            } catch {
                await MainActor.run {
                    errorLabel.text = "连接失败: \(error.localizedDescription)"
                    loading.stopAnimating()
                    connectButton.isEnabled = true
                    if UserDefaults.standard.string(forKey: "serverURL") != nil {
                        self.offlineButton.isHidden = false
                    }
                }
            }
        }
    }

    @objc private func goOffline() {
        guard let saved = UserDefaults.standard.string(forKey: "serverURL") else { return }
        AppState.shared.serverURL = saved
        AppState.shared.isConnected = false
        let shelf = ShelfViewController()
        navigationController?.setViewControllers([shelf], animated: true)
    }

    private func setupOfflineButton() {
        offlineButton.setTitle("离线阅读", for: .normal)
        offlineButton.titleLabel?.font = .systemFont(ofSize: 15)
        offlineButton.setTitleColor(.systemBlue, for: .normal)
        offlineButton.isHidden = true
        offlineButton.addTarget(self, action: #selector(goOffline), for: .touchUpInside)
        view.addSubview(offlineButton)
        offlineButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            offlineButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            offlineButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
        ])
    }
}

extension SetupViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        connect()
        return true
    }
}
