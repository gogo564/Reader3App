import SwiftUI

struct ShelfView: View {
    @State private var books: [Book] = []
    @State private var isLoading = true
    @State private var errorMsg: String?

    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("加载书架...")
                } else if let error = errorMsg {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                        Button("重试") { loadShelf() }
                    }
                } else if books.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("书架是空的")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("去搜索添加书籍吧")
                            .foregroundColor(Color.tertiary)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(books) { book in
                                NavigationLink(destination: ReaderView(book: book)) {
                                    BookCard(book: book)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("书架")
            .refreshable { loadShelf() }
            .onAppear { loadShelf() }
        }
    }

    private func loadShelf() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let shelf = try await ReaderAPI.shared.getShelf()
                await MainActor.run {
                    books = shelf
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct BookCard: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let cover = book.coverUrl, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(height: 160)
                .clipped()
                .cornerRadius(8)
            } else {
                Color.gray.opacity(0.2)
                    .frame(height: 160)
                    .cornerRadius(8)
                    .overlay {
                        Image(systemName: "book")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    }
            }

            Text(book.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)

            if let author = book.author {
                Text(author)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .foregroundColor(.primary)
    }
}
