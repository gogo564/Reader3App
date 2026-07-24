import SwiftUI

struct SearchView: View {
    @State private var keyword = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    TextField("搜索书名或作者", text: $keyword)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onSubmit { search() }

                    Button(action: search) {
                        if isSearching {
                            ProgressView()
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .disabled(keyword.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                }
                .padding()

                if let error = errorMsg {
                    Spacer()
                    Text(error)
                        .foregroundColor(.secondary)
                    Spacer()
                } else if results.isEmpty && !isSearching {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("搜索全网小说")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(results) { result in
                        NavigationLink(destination: ReaderView(book: result.toBook())) {
                            SearchResultRow(result: result)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索")
        }
    }

    private func search() {
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return }
        isSearching = true
        errorMsg = nil
        Task {
            do {
                let books = try await ReaderAPI.shared.searchBooks(keyword: kw)
                await MainActor.run {
                    results = books
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            if let cover = result.coverUrl, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: 50, height: 70)
                .clipped()
                .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .fontWeight(.medium)
                if let author = result.author {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let origin = result.origin {
                    Text(origin)
                        .font(.caption2)
                        .foregroundColor(Color.tertiary)
                        .lineLimit(1)
                }
                if let intro = result.intro {
                    Text(intro)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension SearchResult {
    func toBook() -> Book {
        Book(
            bookUrl: bookUrl,
            name: name,
            author: author,
            kind: kind,
            coverUrl: coverUrl,
            origin: origin,
            intro: intro,
            totalChapterNum: nil,
            order: nil,
            customOrder: nil
        )
    }
}
