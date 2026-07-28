import UIKit

class RegisterViewController: UIViewController {
    var serverURL: String = ""

    private let urlField = UITextField()
    private let userField = UITextField()
    private let passField = UITextField()
    private let confirmField = UITextField()
    private let registerButton = UIButton(type: .system)
    private let loading = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "注册新账号"
        view.backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:))))
        setupUI()
    }

    private func setupUI() {
        urlField.text = serverURL
        urlField.placeholder = "服务器地址"
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
        passField.returnKeyType = .next
        passField.delegate = self
        view.addSubview(passField)
        passField.translatesAutoresizingMaskIntoConstraints = false

        confirmField.placeholder = "确认密码"
        confirmField.borderStyle = .roundedRect
        confirmField.isSecureTextEntry = true
        confirmField.returnKeyType = .go
        confirmField.delegate = self
        view.addSubview(confirmField)
        confirmField.translatesAutoresizingMaskIntoConstraints = false

        registerButton.setTitle("注 册", for: .normal)
        registerButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        registerButton.backgroundColor = UIColor(red: 253/255, green: 85/255, blue: 103/255, alpha: 1)
        registerButton.setTitleColor(.white, for: .normal)
        registerButton.layer.cornerRadius = 8
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

        let helpLabel = UILabel()
        helpLabel.text = "注册成功后返回登录页"
        helpLabel.font = .systemFont(ofSize: 12)
        helpLabel.textColor = .secondaryLabel
        helpLabel.textAlignment = .center
        view.addSubview(helpLabel)
        helpLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            urlField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            urlField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
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
            confirmField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            confirmField.topAnchor.constraint(equalTo: passField.bottomAnchor, constant: 10),
            confirmField.widthAnchor.constraint(equalToConstant: 300),
            confirmField.heightAnchor.constraint(equalToConstant: 40),
            registerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            registerButton.topAnchor.constraint(equalTo: confirmField.bottomAnchor, constant: 20),
            registerButton.widthAnchor.constraint(equalToConstant: 200),
            registerButton.heightAnchor.constraint(equalToConstant: 44),
            loading.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loading.topAnchor.constraint(equalTo: registerButton.bottomAnchor, constant: 12),
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: loading.bottomAnchor, constant: 6),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            helpLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helpLabel.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 8),
        ])
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
        guard let confirm = confirmField.text, confirm == password else {
            errorLabel.text = "两次密码不一致"
            return
        }
        errorLabel.text = nil
        loading.startAnimating()
        registerButton.isEnabled = false

        if !addr.hasPrefix("http://") && !addr.hasPrefix("https://") {
            addr = "http://" + addr
        }

        AppState.shared.serverURL = addr
        Task {
            do {
                _ = try await NetworkService.shared.login(username: username, password: password, isLogin: false)
                await MainActor.run {
                    loading.stopAnimating()
                    if let nav = navigationController,
                       let setup = nav.viewControllers.first(where: { $0 is SetupViewController }) as? SetupViewController {
                        setup.showRegisterSuccess()
                        navigationController?.popToViewController(setup, animated: true)
                    } else {
                        navigationController?.popViewController(animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    errorLabel.text = "注册失败: \(error.localizedDescription)"
                    loading.stopAnimating()
                    registerButton.isEnabled = true
                    let alert = UIAlertController(title: "注册失败", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "确定", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
}

extension RegisterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == urlField { userField.becomeFirstResponder() }
        else if textField == userField { passField.becomeFirstResponder() }
        else if textField == passField { confirmField.becomeFirstResponder() }
        else if textField == confirmField { doRegister() }
        return true
    }
}
