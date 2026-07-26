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
    }

    func removeMark() -> Bool {
        guard let record = recordModel else { return false }
        if let index = markModels.firstIndex(where: { $0.chapterID == record.chapterModel.id && $0.location.intValue == record.locationFirst.intValue }) {
            markModels.remove(at: index)
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
    }

    func modifyChapterList(chapterListModels: [DZMReadChapterListModel]) {
        self.chapterListModels = chapterListModels
    }
}
