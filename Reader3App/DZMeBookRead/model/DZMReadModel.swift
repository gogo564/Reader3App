import UIKit

class DZMReadModel: NSObject {
    var bookID: String!
    var recordModel: DZMReadRecordModel!
    var chapterListModels: [DZMReadChapterListModel]! = []
    var markModels: [DZMReadMarkModel]! = []
    var bookName: String?

    convenience init(bookID: String, chapterModels: [Chapter]) {
        self.init()
        self.bookID = bookID
        self.bookName = ""

        for cm in chapterModels {
            let listModel = DZMReadChapterListModel()
            listModel.id = NSNumber(value: cm.index)
            listModel.name = cm.title
            listModel.bookID = bookID
            chapterListModels.append(listModel)
        }
    }

    var configure: DZMReadConfigure! { DZMReadConfigure.shared() }

    var isExistMark: Bool {
        guard let record = recordModel else { return false }
        return markModels.contains { $0.chapterID == record.chapterModel.id && $0.location.intValue == record.locationFirst.intValue }
    }

    func insetMark() {
        let mark = DZMReadMarkModel()
        mark.bookID = bookID
        mark.chapterID = recordModel.chapterModel.id
        mark.location = recordModel.locationFirst
        mark.content = recordModel.contentString
        mark.name = recordModel.chapterName
        mark.time = NSNumber(value: Timer1970())
        markModels.insert(mark, at: 0)
        saveMarks()
    }

    func removeMark() -> Bool {
        guard let record = recordModel else { return false }
        if let index = markModels.firstIndex(where: { $0.chapterID == record.chapterModel.id && $0.location.intValue == record.locationFirst.intValue }) {
            markModels.remove(at: index)
            saveMarks()
            return true
        }
        return false
    }

    func removeMark(chapterID: NSInteger) -> Bool {
        if let index = markModels.firstIndex(where: { $0.chapterID.intValue == chapterID }) {
            markModels.remove(at: index)
            return true
        }
        return false
    }

    func removeAllMark() {
        markModels.removeAll()
        saveMarks()
    }

    func modifyChapterList(chapterListModels: [DZMReadChapterListModel]) {
        self.chapterListModels = chapterListModels
    }

    func saveMarks() {
        let key = "bookmarks_\(bookID ?? "")"
        let list = markModels.map { m in
            ["bookID": m.bookID ?? "", "chapterID": m.chapterID?.intValue ?? 0,
             "name": m.name ?? "", "content": m.content ?? "",
             "time": m.time?.int64Value ?? 0, "location": m.location?.intValue ?? 0]
        }
        if let data = try? JSONSerialization.data(withJSONObject: list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadMarks() {
        let key = "bookmarks_\(bookID ?? "")"
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        markModels = list.map { d in
            let m = DZMReadMarkModel()
            m.bookID = d["bookID"] as? String
            m.chapterID = NSNumber(value: d["chapterID"] as? Int ?? 0)
            m.name = d["name"] as? String
            m.content = d["content"] as? String
            m.time = NSNumber(value: d["time"] as? Int64 ?? 0)
            m.location = NSNumber(value: d["location"] as? Int ?? 0)
            return m
        }
    }
}
