import UIKit

class DZMReadRecordModel: NSObject {
    var bookID: String!
    var chapterModel: DZMReadChapterModel!
    var page: NSNumber! = NSNumber(value: 0)
    var isLastPage: Bool! { page.intValue >= (chapterModel.pageCount?.intValue ?? 1) - 1 }
    var isFirstPage: Bool! { page.intValue <= 0 }
    var isLastChapter: Bool! { chapterModel.isLastChapter }
    var isFirstChapter: Bool! { chapterModel.isFirstChapter }
    var locationFirst: NSNumber! { chapterModel.locationFirst(page: page.intValue) }
    var locationLast: NSNumber! { chapterModel.locationLast(page: page.intValue) }
    var contentString: String! { chapterModel.contentString(page: page.intValue) }
    var contentAttributedString: NSAttributedString! { chapterModel.contentAttributedString(page: page.intValue) }
    var chapterName: String! { chapterModel.name }
    var chapterID: NSNumber! { chapterModel.id }
    var previousChapterID: NSNumber! { chapterModel.previousChapterID }
    var nextChapterID: NSNumber! { chapterModel.nextChapterID }

    func copyModel() -> DZMReadRecordModel {
        let m = DZMReadRecordModel()
        m.bookID = bookID
        m.chapterModel = chapterModel
        m.page = page
        return m
    }

    func modify(chapterID: NSNumber!, toPage: NSInteger, isSave: Bool = false) {
        if let m = chapterModel, chapterModel?.id == chapterID {
            page = NSNumber(value: toPage)
        }
    }

    func modify(chapterID: NSNumber!, location: NSInteger, isSave: Bool = false) {
        if chapterModel?.id == chapterID {
            page = chapterModel.page(location: location)
        }
    }

    func previousChapter() { modify(chapterID: chapterModel.previousChapterID, toPage: 0) }
    func nextChapter() { modify(chapterID: chapterModel.nextChapterID, toPage: 0) }
    func previousPage() { if !isFirstPage { page = NSNumber(value: page.intValue - 1) } }
    func nextPage() { if !isLastPage { page = NSNumber(value: page.intValue + 1) } }

    func modify(chapterModel cm: DZMReadChapterModel?, page p: NSInteger) {
        if let cm = cm {
            chapterModel = cm
            page = NSNumber(value: p)
        }
    }

    func updateFont() {
        chapterModel?.updateFont()
        if chapterModel != nil {
            if page.intValue >= chapterModel.pageCount.intValue {
                page = NSNumber(value: 0)
            }
        }
    }
}
