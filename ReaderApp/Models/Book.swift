import Foundation

struct Book: Codable, Identifiable {
    var id: String { bookUrl }
    let bookUrl: String
    let name: String
    let author: String?
    let kind: String?
    let coverUrl: String?
    let origin: String?
    let intro: String?
    let totalChapterNum: Int?
    let order: Int?
    let customOrder: Int?

    enum CodingKeys: String, CodingKey {
        case bookUrl, name, author, kind, coverUrl, origin, intro
        case totalChapterNum, order, customOrder
    }
}

struct SearchResult: Codable, Identifiable {
    var id: String { bookUrl }
    let bookUrl: String
    let name: String
    let author: String?
    let kind: String?
    let coverUrl: String?
    let origin: String?
    let intro: String?
    let bookSourceUrl: String?

    enum CodingKeys: String, CodingKey {
        case bookUrl, name, author, kind, coverUrl, origin, intro, bookSourceUrl
    }
}

struct Chapter: Codable, Identifiable {
    var id: String { url }
    let url: String
    let title: String
    let index: Int
}

struct SearchMultiResponse: Codable {
    let lastIndex: Int
    let list: [SearchResult]
}
