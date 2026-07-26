import UIKit

extension DZMReadModel {

    func insetMark(recordModel: DZMReadRecordModel? = nil) {
        let recordModel = (recordModel ?? self.recordModel)!
        let markModel = DZMReadMarkModel()
        markModel.bookID = recordModel.bookID
        markModel.chapterID = recordModel.chapterModel.id
        if recordModel.pageModel.isHomePage {
            markModel.name = "(无章节名)"
            markModel.content = bookName
        } else {
            markModel.name = recordModel.chapterModel.name
            markModel.content = recordModel.contentString.removeSEHeadAndTail.removeEnterAll
        }
        markModel.time = NSNumber(value: Timer1970())
        markModel.location = recordModel.locationFirst
        if markModels.isEmpty {
            markModels.append(markModel)
        } else {
            markModels.insert(markModel, at: 0)
        }
    }

    func removeMark(index: NSInteger) -> Bool {
        markModels.remove(at: index)
        return true
    }

    func removeMark(recordModel: DZMReadRecordModel? = nil) -> Bool {
        let recordModel = (recordModel ?? self.recordModel)!
        let markModel = isExistMark(recordModel: recordModel)
        if markModel != nil {
            let index = markModels.firstIndex(of: markModel!)!
            return removeMark(index: index)
        }
        return false
    }

    func isExistMark(recordModel: DZMReadRecordModel? = nil) -> DZMReadMarkModel? {
        if markModels.isEmpty { return nil }
        let recordModel = (recordModel ?? self.recordModel)!
        let locationFirst = recordModel.locationFirst!
        let locationLast = recordModel.locationLast!
        for markModel in markModels {
            if markModel.chapterID == recordModel.chapterModel.id {
                if (markModel.location.intValue >= locationFirst.intValue) && (markModel.location.intValue < locationLast.intValue) {
                    return markModel
                }
            }
        }
        return nil
    }
}
