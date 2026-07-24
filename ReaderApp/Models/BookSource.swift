import Foundation

struct BookSource: Codable, Identifiable {
    var id: String { bookSourceUrl ?? bookSourceName ?? UUID().uuidString }
    let bookSourceUrl: String?
    let bookSourceName: String?
    let bookSourceGroup: String?
    let enabled: Bool?
    let weight: Int?

    enum CodingKeys: String, CodingKey {
        case bookSourceUrl, bookSourceName, bookSourceGroup, enabled, weight
    }
}
