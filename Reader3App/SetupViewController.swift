import UIKit

class SetupViewController: UIViewController {
    private let urlField = UITextField()
    private let userField = UITextField()
    private let passField = UITextField()
    private let rememberSwitch = UISwitch()
    private let rememberLabel = UILabel()
    private let loginButton = UIButton(type: .system)
    private let registerButton = UIButton(type: .system)
    private let offlineButton = UIButton(type: .system)
    private let loading = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:))))
        setupUI()
        if let saved = UserDefaults.standard.string(forKey: "serverURL"), !saved.isEmpty {
            urlField.text = saved
            userField.text = UserDefaults.standard.string(forKey: "username") ?? ""
            if UserDefaults.standard.bool(forKey: "rememberPassword"),
               let pwd = UserDefaults.standard.string(forKey: "password") {
                passField.text = pwd
                rememberSwitch.isOn = true
            }
            offlineButton.isHidden = false
        }
    }

    private func setupUI() {
        let icon = UILabel()
        icon.text = "📖"
        icon.font = .systemFont(ofSize: 56)
        icon.textAlignment = .center
        view.addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleL = UILabel()
        titleL.text = "Reader"
        titleL.font = .boldSystemFont(ofSize: 26)
        titleL.textAlignment = .center
        view.addSubview(titleL)
        titleL.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "清风不识字，何故乱翻书"
        subtitle.font = .systemFont(ofSize: 13)
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

        rememberLabel.text = "记住密码"
        rememberLabel.font = .systemFont(ofSize: 14)
        rememberLabel.textColor = .secondaryLabel
        rememberSwitch.onTintColor = UIColor(red: 253/255, green: 85/255, blue: 103/255, alpha: 1)
        let rememberRow = UIStackView(arrangedSubviews: [rememberSwitch, rememberLabel])
        rememberRow.axis = .horizontal
        rememberRow.spacing = 8
        rememberRow.alignment = .center
        view.addSubview(rememberRow)
        rememberRow.translatesAutoresizingMaskIntoConstraints = false

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
        registerButton.addTarget(self, action: #selector(showRegister), for: .touchUpInside)
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

        setupOfflineButton()
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            icon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleL.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleL.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 6),
            subtitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 4),

            urlField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            urlField.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 24),
            urlField.widthAnchor.constraint(equalToConstant: 300),
            urlField.heightAnchor.constraint(equalToConstant: 40),
            userField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            userField.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 10),
            userField.widthAnchor.constraint(equalToConstant: 300),
            userField.heightAnchor.constraint(equalToConstant: 40),
            passField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            passField.topAnchor.constraint(equalTo: userField.bottomAnchor, constant: 10),
            passField.widthAnchor.constraint(equalToConstant: 300),
            passField.heightAnchor.constraint(equalToConstant: 40),

            rememberRow.topAnchor.constraint(equalTo: passField.bottomAnchor, constant: 8),
            rememberRow.trailingAnchor.constraint(equalTo: passField.trailingAnchor),

            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.topAnchor.constraint(equalTo: rememberRow.bottomAnchor, constant: 16),
            loginButton.widthAnchor.constraint(equalToConstant: 200),
            loginButton.heightAnchor.constraint(equalToConstant: 44),
            registerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            registerButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 6),
            loading.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loading.topAnchor.constraint(equalTo: registerButton.bottomAnchor, constant: 10),
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: loading.bottomAnchor, constant: 6),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
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
            offlineButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 12),
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
                    if rememberSwitch.isOn {
                        UserDefaults.standard.set(true, forKey: "rememberPassword")
                        UserDefaults.standard.set(password, forKey: "password")
                    } else {
                        UserDefaults.standard.removeObject(forKey: "rememberPassword")
                        UserDefaults.standard.removeObject(forKey: "password")
                    }
                    AppState.shared.isConnected = true
                    AppState.shared.isLoggedIn = true
                    loading.stopAnimating()
                    let shelf = ShelfViewController()
                    navigationController?.setViewControllers([shelf], animated: true)
                }
            } catch {
                await MainActor.run {
                    loading.stopAnimating()
                    loginButton.isEnabled = true
                    registerButton.isEnabled = true
                    if UserDefaults.standard.string(forKey: "serverURL") != nil {
                        offlineButton.isHidden = false
                    }
                    let msg = error.localizedDescription
                    errorLabel.text = msg
                    let alert = UIAlertController(title: "登录失败", message: msg, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }

    @objc private func showRegister() {
        let vc = RegisterViewController()
        vc.serverURL = urlField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func goOffline() {
        guard let saved = UserDefaults.standard.string(forKey: "serverURL") else { return }
        AppState.shared.serverURL = saved
        AppState.shared.isConnected = false
        AppState.shared.isLoggedIn = false
        let shelf = ShelfViewController()
        navigationController?.setViewControllers([shelf], animated: true)
    }

    func showRegisterSuccess() {
        errorLabel.text = "注册成功，请登录"
        errorLabel.textColor = .systemGreen
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
