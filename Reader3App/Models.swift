import Foundation

struct Book: Codable, Identifiable, Hashable {
    var id: String { bookUrl }
    let bookUrl: String
    let name: String
    let author: String?
    let kind: String?
    let coverUrl: String?
    let customCoverUrl: String?
    let origin: String?
    let originName: String?
    let intro: String?
    let totalChapterNum: Int?
    let order: Int?
    let durChapterTitle: String?
    let durChapterIndex: Int?
    let durChapterPos: Int?
    let durChapterTime: Int64?
    let latestChapterTitle: String?
    let wordCount: String?
    let type: Int?
    let group: Int?
    let tocUrl: String?
    let canUpdate: Bool?
    let charset: String?
    let lastCheckTime: Int64?
    let index: Int?

    enum CodingKeys: String, CodingKey {
        case bookUrl, name, author, kind, coverUrl, customCoverUrl
        case origin, originName, intro, totalChapterNum, order
        case durChapterTitle, durChapterIndex, durChapterPos, durChapterTime
        case latestChapterTitle, wordCount, type, group, tocUrl
        case canUpdate, charset, lastCheckTime, index
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookUrl = try container.decode(String.self, forKey: .bookUrl)
        name = try container.decode(String.self, forKey: .name)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        customCoverUrl = try container.decodeIfPresent(String.self, forKey: .customCoverUrl)
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        originName = try container.decodeIfPresent(String.self, forKey: .originName)
        intro = try container.decodeIfPresent(String.self, forKey: .intro)
        totalChapterNum = try container.decodeIfPresent(Int.self, forKey: .totalChapterNum)
        order = try container.decodeIfPresent(Int.self, forKey: .order)
        durChapterTitle = try container.decodeIfPresent(String.self, forKey: .durChapterTitle)
        durChapterIndex = try container.decodeIfPresent(Int.self, forKey: .durChapterIndex)
        durChapterPos = try container.decodeIfPresent(Int.self, forKey: .durChapterPos)
        durChapterTime = try container.decodeIfPresent(Int64.self, forKey: .durChapterTime)
        latestChapterTitle = try container.decodeIfPresent(String.self, forKey: .latestChapterTitle)
        wordCount = try container.decodeIfPresent(String.self, forKey: .wordCount)
        type = try container.decodeIfPresent(Int.self, forKey: .type)
        group = try container.decodeIfPresent(Int.self, forKey: .group)
        tocUrl = try container.decodeIfPresent(String.self, forKey: .tocUrl)
        canUpdate = try container.decodeIfPresent(Bool.self, forKey: .canUpdate)
        charset = try container.decodeIfPresent(String.self, forKey: .charset)
        lastCheckTime = try container.decodeIfPresent(Int64.self, forKey: .lastCheckTime)
        index = try container.decodeIfPresent(Int.self, forKey: .index)
    }

    init(bookUrl: String, name: String, author: String?, kind: String? = nil,
         coverUrl: String? = nil, customCoverUrl: String? = nil,
         origin: String? = nil, originName: String? = nil, intro: String? = nil,
         totalChapterNum: Int? = nil, order: Int? = nil,
         durChapterTitle: String? = nil, durChapterIndex: Int? = nil,
         durChapterPos: Int? = nil, durChapterTime: Int64? = nil,
         latestChapterTitle: String? = nil, wordCount: String? = nil,
         type: Int? = nil, group: Int? = nil, tocUrl: String? = nil,
         canUpdate: Bool? = nil, charset: String? = nil,
         lastCheckTime: Int64? = nil, index: Int? = nil) {
        self.bookUrl = bookUrl
        self.name = name
        self.author = author
        self.kind = kind
        self.coverUrl = coverUrl
        self.customCoverUrl = customCoverUrl
        self.origin = origin
        self.originName = originName
        self.intro = intro
        self.totalChapterNum = totalChapterNum
        self.order = order
        self.durChapterTitle = durChapterTitle
        self.durChapterIndex = durChapterIndex
        self.durChapterPos = durChapterPos
        self.durChapterTime = durChapterTime
        self.latestChapterTitle = latestChapterTitle
        self.wordCount = wordCount
        self.type = type
        self.group = group
        self.tocUrl = tocUrl
        self.canUpdate = canUpdate
        self.charset = charset
        self.lastCheckTime = lastCheckTime
        self.index = index
    }

    var coverImageURL: URL? {
        let cover = customCoverUrl ?? coverUrl
        guard let c = cover, !c.isEmpty else { return nil }
        if c.hasPrefix("http://") || c.hasPrefix("https://") || c.hasPrefix("//") {
            let cleaned = c.hasPrefix("//") ? "https:" + c : c
            return URL(string: cleaned)
        }
        let base = AppState.shared.baseURL
        return URL(string: base + c)
    }

    func withProgress(index: Int, title: String?, time: Int64, pos: Int? = nil) -> Book {
        Book(bookUrl: bookUrl, name: name, author: author, kind: kind,
             coverUrl: coverUrl, customCoverUrl: customCoverUrl,
             origin: origin, originName: originName, intro: intro,
             totalChapterNum: totalChapterNum, order: order,
             durChapterTitle: title ?? durChapterTitle,
             durChapterIndex: index,
             durChapterPos: pos ?? durChapterPos,
             durChapterTime: time,
             latestChapterTitle: latestChapterTitle, wordCount: wordCount,
             type: type, group: group, tocUrl: tocUrl,
             canUpdate: canUpdate, charset: charset,
             lastCheckTime: lastCheckTime, index: index)
    }

    /// 服务器只保留章节: 更新章节信息并清空页码位置
    func withChapterProgress(index: Int, title: String?, time: Int64) -> Book {
        Book(bookUrl: bookUrl, name: name, author: author, kind: kind,
             coverUrl: coverUrl, customCoverUrl: customCoverUrl,
             origin: origin, originName: originName, intro: intro,
             totalChapterNum: totalChapterNum, order: order,
             durChapterTitle: title ?? durChapterTitle,
             durChapterIndex: index,
             durChapterPos: nil,
             durChapterTime: time,
             latestChapterTitle: latestChapterTitle, wordCount: wordCount,
             type: type, group: group, tocUrl: tocUrl,
             canUpdate: canUpdate, charset: charset,
             lastCheckTime: lastCheckTime, index: index)
    }
}

struct BookGroup: Codable, Identifiable {
    var id: Int { groupId }
    let groupId: Int
    let groupName: String
    let order: Int?
    let show: Bool?
}

struct SearchResult: Codable, Identifiable, Hashable {
    var id: String { bookUrl }
    let bookUrl: String
    let name: String
    let author: String?
    let kind: String?
    let coverUrl: String?
    let origin: String?
    let originName: String?
    let intro: String?
    let latestChapterTitle: String?
    let wordCount: String?
    let type: Int?
    let tocUrl: String?

    var coverImageURL: URL? {
        guard let c = coverUrl, !c.isEmpty else { return nil }
        if c.hasPrefix("http://") || c.hasPrefix("https://") || c.hasPrefix("//") {
            let cleaned = c.hasPrefix("//") ? "https:" + c : c
            return URL(string: cleaned)
        }
        let base = AppState.shared.baseURL
        return URL(string: base + c)
    }
}

struct Chapter: Codable, Identifiable, Hashable {
    var id: String { url }
    let url: String
    let title: String
    let index: Int
    let isVolume: Bool?

    enum CodingKeys: String, CodingKey {
        case url, title, index, isVolume
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        index = try container.decode(Int.self, forKey: .index)
        isVolume = try container.decodeIfPresent(Bool.self, forKey: .isVolume)
    }

    init(url: String, title: String, index: Int, isVolume: Bool? = nil) {
        self.url = url; self.title = title; self.index = index; self.isVolume = isVolume
    }
}

struct BookmarkItem: Codable, Identifiable {
    var id: String { "\(bookUrl)-\(chapterIndex)-\(chapterPos)" }
    let bookUrl: String
    let time: Int64
    let bookName: String
    let bookAuthor: String
    let chapterIndex: Int
    let chapterPos: Int
    let chapterName: String
    let bookText: String
    let content: String
}

struct BookSource: Codable, Identifiable {
    var id: String { bookSourceUrl ?? bookSourceName ?? UUID().uuidString }
    let bookSourceUrl: String?
    let bookSourceName: String?
    let bookSourceGroup: String?
    let bookSourceType: Int?
    let enabled: Bool?
    let weight: Int?
    let exploreUrl: String?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookSourceUrl = try c.decodeIfPresent(String.self, forKey: .bookSourceUrl)
        bookSourceName = try c.decodeIfPresent(String.self, forKey: .bookSourceName)
        bookSourceGroup = try c.decodeIfPresent(String.self, forKey: .bookSourceGroup)
        bookSourceType = try c.decodeIfPresent(Int.self, forKey: .bookSourceType)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
        weight = try c.decodeIfPresent(Int.self, forKey: .weight)
        if let s = try? c.decodeIfPresent(String.self, forKey: .exploreUrl) { exploreUrl = s }
        else if let b = try? c.decodeIfPresent(Bool.self, forKey: .exploreUrl) { exploreUrl = b ? "true" : "false" }
        else { exploreUrl = nil }
    }
}

struct ReplaceRule: Codable, Identifiable {
    var id: String { name + pattern }
    let name: String
    let pattern: String
    let replacement: String
    let scope: String
    let isRegex: Bool
    let isEnabled: Bool
}

struct SearchMultiResponse: Codable {
    let lastIndex: Int
    let list: [SearchResult]
}

struct LoginResult: Codable {
    let username: String?
    let accessToken: String?
}

struct UserInfo: Codable {
    let username: String?
    let enableLocalStore: Bool?
    let enableWebdav: Bool?
    let secure: Bool?
    let secureKey: String?
    let userInfo: UserDetail?
}

struct UserDetail: Codable {
    let username: String?
    let userNS: String?
}

struct BookSourceGroup: Codable {
    let name: String
    let value: String
    let count: Int
}

struct APIDataResponse<T: Codable>: Codable {
    let isSuccess: Bool
    let errorMsg: String?
    let data: T?
}

typealias APIResponse = APIDataResponse
