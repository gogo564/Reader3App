import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var showResetAlert = false

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
                        Text("状态")
                        Spacer()
                        if serverManager.isConnected {
                            Label("已连接", systemImage: "checkmark.circle.fill")
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
                    Button(action: { serverManager.testConnection() }) {
                        Label("重新连接", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("重置设置", systemImage: "trash")
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
            .alert("确认重置", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) { serverManager.reset() }
            } message: {
                Text("重置后需要重新输入服务器地址")
            }
        }
    }
}
