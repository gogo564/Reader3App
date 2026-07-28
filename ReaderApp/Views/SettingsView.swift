import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if let url = serverManager.serverURL {
                        HStack {
                            Text("服务器")
                            Spacer()
                            Text(url)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    HStack {
                        Text("用户")
                        Spacer()
                        Text(serverManager.username)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("状态")
                        Spacer()
                        if serverManager.isConnected {
                            Label("已登录", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("未连接", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("服务器")
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section {
                    Link("Reader 项目主页", destination: URL(string: "https://github.com/hectorqin/reader")!)
                        .font(.footnote)
                    Text("版本 1.0.0")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .alert("退出登录", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("退出", role: .destructive) { serverManager.reset() }
            } message: {
                Text("退出后需要重新输入服务器地址和密码")
            }
        }
    }
}
