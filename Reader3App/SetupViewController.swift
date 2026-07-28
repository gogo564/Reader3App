import UIKit

class SetupViewController: UIViewController {
    private let urlField = UITextField()
    private let userField = UITextField()
    private let passField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let registerButton = UIButton(type: .system)
    private let offlineButton = UIButton(type: .system)
    private let loading = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let registerLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        setupUI()
        if let saved = UserDefaults.standard.string(forKey: "serverURL"), !saved.isEmpty {
            urlField.text = saved
            let savedUser = UserDefaults.standard.string(forKey: "username") ?? ""
            userField.text = savedUser
        }
    }

    private func setupUI() {
        let icon = UILabel()
        icon.text = "📖"
        icon.font = .systemFont(ofSize: 64)
        icon.textAlignment = .center
        view.addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleL = UILabel()
        titleL.text = "Reader"
        titleL.font = .boldSystemFont(ofSize: 28)
        titleL.textAlignment = .center
        view.addSubview(titleL)
        titleL.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "清风不识字，何故乱翻书"
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        view.addSubview(subtitle)
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        urlField.placeholder = "服务器地址 如: 192.168.1.100:4396"
        urlField.borderStyle = .roundedRect
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.keyboardType = .URL
        urlField.returnKeyType = .next
        urlField.delegate = self
        view.addSubview(urlField)
        urlField.translatesAutoresizingMaskIntoConstraints = false

        userField.placeholder = "用户名"
        userField.borderStyle = .roundedRect
        userField.autocapitalizationType = .none
        userField.autocorrectionType = .no
        userField.returnKeyType = .next
        userField.delegate = self
        view.addSubview(userField)
        userField.translatesAutoresizingMaskIntoConstraints = false

        passField.placeholder = "密码"
        passField.borderStyle = .roundedRect
        passField.isSecureTextEntry = true
        passField.returnKeyType = .go
        passField.delegate = self
        view.addSubview(passField)
        passField.translatesAutoresizingMaskIntoConstraints = false

        loginButton.setTitle("登 录", for: .normal)
        loginButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        loginButton.backgroundColor = UIColor(red: 253/255, green: 85/255, blue: 103/255, alpha: 1)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.layer.cornerRadius = 8
        loginButton.addTarget(self, action: #selector(doLogin), for: .touchUpInside)
        view.addSubview(loginButton)
        loginButton.translatesAutoresizingMaskIntoConstraints = false

        registerButton.setTitle("注册新账号", for: .normal)
        registerButton.titleLabel?.font = .systemFont(ofSize: 14)
        registerButton.setTitleColor(.systemBlue, for: .normal)
        registerButton.addTarget(self, action: #selector(doRegister), for: .touchUpInside)
        view.addSubview(registerButton)
        registerButton.translatesAutoresizingMaskIntoConstraints = false

        loading.hidesWhenStopped = true
        view.addSubview(loading)
        loading.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        view.addSubview(errorLabel)
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        registerLabel.textColor = .secondaryLabel
        registerLabel.font = .systemFont(ofSize: 12)
        registerLabel.numberOfLines = 0
        registerLabel.textAlignment = .center
        view.addSubview(registerLabel)
        registerLabel.translatesAutoresizingMaskIntoConstraints = false

        setupOfflineButton()
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            icon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleL.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleL.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 8),
            subtitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 4),
            urlField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            urlField.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 30),
            urlField.widthAnchor.constraint(equalToConstant: 300),
            urlField.heightAnchor.constraint(equalToConstant: 44),
            userField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            userField.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 12),
            userField.widthAnchor.constraint(equalToConstant: 300),
            userField.heightAnchor.constraint(equalToConstant: 44),
            passField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            passField.topAnchor.constraint(equalTo: userField.bottomAnchor, constant: 12),
            passField.widthAnchor.constraint(equalToConstant: 300),
            passField.heightAnchor.constraint(equalToConstant: 44),
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.topAnchor.constraint(equalTo: passField.bottomAnchor, constant: 20),
            loginButton.widthAnchor.constraint(equalToConstant: 200),
            loginButton.heightAnchor.constraint(equalToConstant: 44),
            registerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            registerButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 8),
            loading.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loading.topAnchor.constraint(equalTo: registerButton.bottomAnchor, constant: 12),
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: loading.bottomAnchor, constant: 8),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            registerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            registerLabel.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 4),
            registerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            registerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    private func setupOfflineButton() {
        offlineButton.setTitle("离线阅读 (仅缓存书籍)", for: .normal)
        offlineButton.titleLabel?.font = .systemFont(ofSize: 15)
        offlineButton.setTitleColor(.systemBlue, for: .normal)
        offlineButton.addTarget(self, action: #selector(goOffline), for: .touchUpInside)
        view.addSubview(offlineButton)
        offlineButton.translatesAutoresizingMaskIntoConstraints = false
        offlineButton.isHidden = true
        NSLayoutConstraint.activate([
            offlineButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            offlineButton.topAnchor.constraint(equalTo: registerLabel.bottomAnchor, constant: 16),
        ])
    }

    @objc private func doLogin() {
        guard var addr = urlField.text?.trimmingCharacters(in: .whitespaces), !addr.isEmpty else {
            errorLabel.text = "请输入服务器地址"
            return
        }
        guard let username = userField.text?.trimmingCharacters(in: .whitespaces), !username.isEmpty else {
            errorLabel.text = "请输入用户名"
            return
        }
        guard let password = passField.text, !password.isEmpty else {
            errorLabel.text = "请输入密码"
            return
        }
        errorLabel.text = nil
        registerLabel.text = nil
        loading.startAnimating()
        loginButton.isEnabled = false
        registerButton.isEnabled = false
        offlineButton.isHidden = true

        if !addr.hasPrefix("http://") && !addr.hasPrefix("https://") {
            addr = "http://" + addr
        }

        AppState.shared.serverURL = addr
        Task {
            do {
                try await NetworkService.shared.login(username: username, password: password)
                await MainActor.run {
                    UserDefaults.standard.set(addr, forKey: "serverURL")
                    UserDefaults.standard.set(username, forKey: "username")
                    AppState.shared.isConnected = true
                    AppState.shared.isLoggedIn = true
                    loading.stopAnimating()
                    let shelf = ShelfViewController()
                    navigationController?.setViewControllers([shelf], animated: true)
                }
            } catch {
                await MainActor.run {
                    errorLabel.text = "登录失败: \(error.localizedDescription)"
                    loading.stopAnimating()
                    loginButton.isEnabled = true
                    registerButton.isEnabled = true
                    if UserDefaults.standard.string(forKey: "serverURL") != nil {
                        offlineButton.isHidden = false
                    }
                }
            }
        }
    }

    @objc private func doRegister() {
        guard var addr = urlField.text?.trimmingCharacters(in: .whitespaces), !addr.isEmpty else {
            errorLabel.text = "请输入服务器地址"
            return
        }
        guard let username = userField.text?.trimmingCharacters(in: .whitespaces), !username.isEmpty else {
            errorLabel.text = "请输入用户名"
            return
        }
        guard let password = passField.text, !password.isEmpty else {
            errorLabel.text = "请输入密码"
            return
        }
        errorLabel.text = nil
        registerLabel.text = nil
        loading.startAnimating()
        loginButton.isEnabled = false
        registerButton.isEnabled = false

        if !addr.hasPrefix("http://") && !addr.hasPrefix("https://") {
            addr = "http://" + addr
        }

        AppState.shared.serverURL = addr
        Task {
            do {
                _ = try await NetworkService.shared.login(username: username, password: password, isLogin: false)
                await MainActor.run {
                    registerLabel.text = "注册成功！请登录"
                    loading.stopAnimating()
                    loginButton.isEnabled = true
                    registerButton.isEnabled = true
                }
            } catch {
                await MainActor.run {
                    registerLabel.text = "注册失败: \(error.localizedDescription)"
                    loading.stopAnimating()
                    loginButton.isEnabled = true
                    registerButton.isEnabled = true
                }
            }
        }
    }

    @objc private func goOffline() {
        guard let saved = UserDefaults.standard.string(forKey: "serverURL") else { return }
        AppState.shared.serverURL = saved
        AppState.shared.isConnected = false
        AppState.shared.isLoggedIn = false
        let shelf = ShelfViewController()
        navigationController?.setViewControllers([shelf], animated: true)
    }
}

extension SetupViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == urlField { userField.becomeFirstResponder() }
        else if textField == userField { passField.becomeFirstResponder() }
        else if textField == passField { doLogin() }
        return true
    }
}
