# Reader App - iOS 原生客户端

阅读 3 服务器版 (hectorqin/reader) 的 iOS 原生客户端。

## 功能

- 书架管理：查看、添加、删除书籍
- 全网搜索：通过书源搜索小说
- 在线阅读：分章阅读，支持上下章切换
- 阅读设置：字号、背景色调节
- 多服务器支持：可切换 Reader 服务器

## 构建方法

### 需要环境
- macOS 14+ (Sonoma)
- Xcode 15+
- Apple Developer 账号（免费即可，7天有效期）

### 构建步骤

#### 方法一：Xcode 直接构建
```bash
# 1. 打开项目
open ReaderApp.xcodeproj

# 2. 在 Xcode 中：
#    - 选择你的 Team (Signing & Capabilities)
#    - 修改 Bundle Identifier 为唯一值
#    - 连接 iPhone
#    - Cmd+R 运行
```

#### 方法二：GitHub Actions 自动构建
将本仓库 push 到 GitHub，GitHub Actions 会自动构建 IPA。

在 GitHub 仓库设置中添加 Secrets：
- `APPLE_DEVELOPER_EMAIL` - 你的 Apple ID
- `APPLE_DEVELOPER_PASSWORD` - Apple ID 密码（需开启 App-Specific Password）
- `BUNDLE_ID` - 例如 `com.yourname.readerapp`

然后前往 Actions 页面下载构建好的 IPA。

### 安装到 iPhone
- 使用 AltStore 或 SideStore 侧载 IPA
- 或使用 Xcode 直接安装

## 连接服务器

1. 打开 App，输入 Reader 服务器地址
   - 例如: `http://192.168.1.85:4396`
2. 如果开启多用户模式，输入用户名密码
3. 点击"连接服务器"

## API 说明

本 App 使用 Reader 的 REST API，主要接口：
- `GET /getShelfBookWithCacheInfo` - 获取书架
- `GET /searchBookContent?keyword=xxx` - 搜索
- `GET /getBookContent?url=xxx` - 获取章节内容
- `POST /saveBook` - 添加到书架
- `POST /deleteBook` - 从书架删除
