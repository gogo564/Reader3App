import SwiftUI

struct ReaderView: View {
    let book: Book
    @State private var chapters: [Chapter] = []
    @State private var currentChapterIndex = 0
    @State private var content = "加载中..."
    @State private var isLoading = true
    @State private var showChapters = false
    @State private var fontSize: CGFloat = 20
    @State private var bgColor = Color(UIColor.systemBackground)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(content)
                    .font(.system(size: fontSize))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            HStack {
                Button(action: prevChapter) {
                    Image(systemName: "chevron.left")
                    Text("上一章")
                }
                .disabled(currentChapterIndex <= 0)

                Spacer()

                Button(action: { showChapters = true }) {
                    VStack(spacing: 2) {
                        Text("第 \(currentChapterIndex + 1)/\(chapters.count) 章")
                            .font(.caption)
                        Text(chapters[safe: currentChapterIndex]?.title ?? "")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: nextChapter) {
                    Text("下一章")
                    Image(systemName: "chevron.right")
                }
                .disabled(currentChapterIndex >= chapters.count - 1)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("字号") {
                        Button("缩小") { fontSize = max(12, fontSize - 2) }
                        Button("放大") { fontSize = min(36, fontSize + 2) }
                    }
                    Section("背景") {
                        Button("默认") { bgColor = Color(UIColor.systemBackground) }
                        Button("护眼") { bgColor = Color(red: 0.95, green: 0.93, blue: 0.85) }
                        Button("夜间") { bgColor = Color(UIColor.systemBackground).opacity(0.9) }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                }
            }
        }
        .background(bgColor)
        .sheet(isPresented: $showChapters) {
            ChapterListView(
                chapters: chapters,
                currentIndex: currentChapterIndex,
                onSelect: { index in
                    currentChapterIndex = index
                    showChapters = false
                    loadContent()
                }
            )
        }
        .onAppear {
            if chapters.isEmpty {
                loadChapters()
            } else {
                loadContent()
            }
        }
    }

    private func loadChapters() {
        isLoading = true
        Task {
            do {
                let chapterList = try await ReaderAPI.shared.getChapterList(
                    bookURL: book.bookUrl,
                    sourceURL: book.origin ?? ""
                )
                await MainActor.run {
                    chapters = chapterList
                    isLoading = false
                    if !chapterList.isEmpty {
                        loadContent()
                    }
                }
            } catch {
                await MainActor.run {
                    content = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func loadContent() {
        guard currentChapterIndex < chapters.count else { return }
        content = "加载中..."
        Task {
            do {
                let text = try await ReaderAPI.shared.getChapterContent(
                    bookURL: book.bookUrl,
                    sourceURL: book.origin ?? "",
                    index: chapters[currentChapterIndex].index
                )
                await MainActor.run { content = text }
            } catch {
                await MainActor.run { content = "加载失败: \(error.localizedDescription)" }
            }
        }
    }

    private func prevChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        loadContent()
    }

    private func nextChapter() {
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
        loadContent()
    }
}

struct ChapterListView: View {
    let chapters: [Chapter]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationView {
            List(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                Button(action: { onSelect(index) }) {
                    HStack {
                        Text(chapter.title)
                            .foregroundColor(.primary)
                        Spacer()
                        if index == currentIndex {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("目录")
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
