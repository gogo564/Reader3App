import UIKit

extension DZMReadController {

    func GetReadViewController(recordModel: DZMReadRecordModel!) -> DZMReadViewController? {
        guard let rm = recordModel else { return nil }
        if DZMReadConfigure.shared().openLongPress {
            let vc = DZMReadLongPressViewController()
            vc.recordModel = rm
            vc.readModel = readModel
            return vc
        } else {
            let vc = DZMReadViewController()
            vc.recordModel = rm
            vc.readModel = readModel
            return vc
        }
    }

    func GetCurrentReadViewController(isUpdateFont: Bool = false) -> DZMReadViewController? {
        if DZMReadConfigure.shared().effectType != .scroll {
            if isUpdateFont { readModel.recordModel.updateFont() }
            return GetReadViewController(recordModel: readModel.recordModel.copyModel())
        }
        return nil
    }

    func GetAboveReadViewController() -> UIViewController? {
        guard let rm = GetAboveReadRecordModel(recordModel: readModel.recordModel) else { return nil }
        return GetReadViewController(recordModel: rm)
    }

    func GetReadViewBGController(recordModel: DZMReadRecordModel!, targetView: UIView? = nil) -> DZMReadViewBGController {
        let vc = DZMReadViewBGController()
        vc.recordModel = recordModel
        if let tv = targetView { vc.targetView = tv }
        else { vc.targetView = GetReadViewController(recordModel: recordModel)?.view }
        return vc
    }

    func GetBelowReadViewController() -> UIViewController? {
        guard let rm = GetBelowReadRecordModel(recordModel: readModel.recordModel) else { return nil }
        return GetReadViewController(recordModel: rm)
    }

    func GoToChapter(chapterID: NSNumber!, toPage: NSInteger = 0) {
        GoToChapter(chapterID: chapterID, number: toPage, isLocation: false)
    }

    func GoToChapter(chapterID: NSNumber!, location: NSInteger) {
        GoToChapter(chapterID: chapterID, number: location, isLocation: true)
    }

    private func GoToChapter(chapterID: NSNumber!, number: NSInteger, isLocation: Bool) {
        let bookID = readModel.bookID!
        let recordModel = readModel.recordModel.copyModel()
        let isExist = readModel.recordModel.chapterModel?.id == chapterID

        if isExist {
            if isLocation {
                recordModel.modify(chapterID: chapterID, location: number, isSave: false)
            } else {
                recordModel.modify(chapterID: chapterID, toPage: number, isSave: false)
            }
            updateReadRecord(recordModel: recordModel)
            creatPageController(displayController: GetReadViewController(recordModel: recordModel))
        } else {
            loadAndShowChapter(bookID: bookID, chapterID: chapterID, recordModel: recordModel, toPage: number, isLocation: isLocation)
        }
    }

    private func loadAndShowChapter(bookID: String, chapterID: NSNumber, recordModel: DZMReadRecordModel, toPage: NSInteger, isLocation: Bool) {
        let index = chapterID.intValue
        Task {
            do {
                let content = try await chapterContent?(bookID, index) ?? ""
                let title = catalogChapters[safe: index]?.title ?? ""
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    let chapterModel = DZMReadChapterModel()
                    chapterModel.bookID = bookID
                    chapterModel.id = chapterID
                    chapterModel.name = title
                    chapterModel.content = DZMReadParser.contentTypesetting(content: content)
                    chapterModel.priority = NSNumber(value: index)
                    if index > 0 {
                        chapterModel.previousChapterID = NSNumber(value: index - 1)
                    } else {
                        chapterModel.previousChapterID = DZM_READ_NO_MORE_CHAPTER
                    }
                    if index < catalogChapters.count - 1 {
                        chapterModel.nextChapterID = NSNumber(value: index + 1)
                    } else {
                        chapterModel.nextChapterID = DZM_READ_NO_MORE_CHAPTER
                    }
                    chapterModel.updateFont()

                    let newRecord = DZMReadRecordModel()
                    newRecord.bookID = bookID
                    newRecord.chapterModel = chapterModel
                    if toPage == DZM_READ_LAST_PAGE {
                        newRecord.page = NSNumber(value: max(chapterModel.pageCount.intValue - 1, 0))
                    } else {
                        newRecord.page = isLocation ? chapterModel.page(location: toPage) : NSNumber(value: toPage)
                    }
                    self.updateReadRecord(recordModel: newRecord)
                    self.creatPageController(displayController: self.GetReadViewController(recordModel: newRecord))
                }
            } catch {
                await MainActor.run {
                    DZMLog("加载章节失败: \(error)")
                }
            }
        }
    }

    func GetAboveReadRecordModel(recordModel: DZMReadRecordModel!) -> DZMReadRecordModel? {
        guard recordModel.chapterModel != nil else { return nil }
        let record = recordModel.copyModel()
        crashLog("[flip-A] cur=\(record.chapterModel.id?.intValue ?? -1),\(record.page?.intValue ?? -1)/\(record.chapterModel.pageCount?.intValue ?? -1)")
        let bookID = record.bookID!
        let chapterID = record.chapterModel.previousChapterID

        if record.isFirstChapter && record.isFirstPage {
            DZMLog("已经是第一页了")
            return nil
        }

        if record.isFirstPage {
            if !recordModel.isFirstChapter, let cid = chapterID {
                let prevIndex = cid.intValue
                if let cached = CacheManager.shared.getCachedChapter(bookUrl: bookID, index: prevIndex) {
                    let cm = buildChapterModel(bookID: bookID, chapterID: cid, index: prevIndex, content: cached)
                    let nr = DZMReadRecordModel()
                    nr.bookID = bookID
                    nr.chapterModel = cm
                    nr.page = NSNumber(value: max(cm.pageCount.intValue - 1, 0))
                    updateReadRecord(recordModel: nr)
                    return nr
                }
                loadAndShowChapter(bookID: bookID, chapterID: cid, recordModel: record, toPage: DZM_READ_LAST_PAGE, isLocation: false)
            }
            return nil
        } else {
            record.previousPage()
        }
        return record
    }

    func GetBelowReadRecordModel(recordModel: DZMReadRecordModel!) -> DZMReadRecordModel? {
        guard recordModel.chapterModel != nil else { return nil }
        let record = recordModel.copyModel()
        crashLog("[flip-B] cur=\(record.chapterModel.id?.intValue ?? -1),\(record.page?.intValue ?? -1)/\(record.chapterModel.pageCount?.intValue ?? -1)")
        let bookID = record.bookID!
        let chapterID = record.chapterModel.nextChapterID

        if record.isLastChapter && record.isLastPage {
            DZMLog("已经是最后一页了")
            return nil
        }

        if record.isLastPage {
            if !record.isLastChapter, let cid = chapterID {
                let nextIndex = cid.intValue
                if let cached = CacheManager.shared.getCachedChapter(bookUrl: bookID, index: nextIndex) {
                    let cm = buildChapterModel(bookID: bookID, chapterID: cid, index: nextIndex, content: cached)
                    let nr = DZMReadRecordModel()
                    nr.bookID = bookID
                    nr.chapterModel = cm
                    nr.page = NSNumber(value: 0)
                    updateReadRecord(recordModel: nr)
                    return nr
                }
                loadAndShowChapter(bookID: bookID, chapterID: cid, recordModel: record, toPage: 0, isLocation: false)
            }
            return nil
        } else {
            record.nextPage()
        }
        return record
    }

    private func buildChapterModel(bookID: String, chapterID: NSNumber, index: Int, content: String) -> DZMReadChapterModel {
        let cm = DZMReadChapterModel()
        cm.bookID = bookID
        cm.id = chapterID
        cm.name = catalogChapters[safe: index]?.title ?? ""
        cm.content = DZMReadParser.contentTypesetting(content: content)
        cm.priority = NSNumber(value: index)
        cm.previousChapterID = index > 0 ? NSNumber(value: index - 1) : DZM_READ_NO_MORE_CHAPTER
        cm.nextChapterID = index < catalogChapters.count - 1 ? NSNumber(value: index + 1) : DZM_READ_NO_MORE_CHAPTER
        cm.updateFont()
        return cm
    }

    func updateReadRecord(controller: DZMReadViewController!) {
        updateReadRecord(recordModel: controller?.recordModel)
    }

    func updateReadRecord(recordModel: DZMReadRecordModel!) {
        if recordModel != nil {
            let oldIdx = readModel.recordModel.chapterModel?.id?.intValue ?? -1
            let newIdx = recordModel.chapterModel?.id?.intValue ?? -1
            let oldPg = readModel.recordModel.page?.intValue ?? -1
            let newPg = recordModel.page?.intValue ?? -1
            if newIdx != oldIdx || newPg != oldPg {
                let stack = Thread.callStackSymbols.dropFirst(2).prefix(4).joined(separator: " <= ")
                crashLog("[rec-change] old(\(oldIdx),\(oldPg)) new(\(newIdx),\(newPg)) pc=\(recordModel.chapterModel?.pageCount?.intValue ?? -1) loc=\(recordModel.locationFirst?.intValue ?? -1) \(stack)")
            }
            readModel.recordModel = recordModel
            DZM_READ_RECORD_CURRENT_CHAPTER_LOCATION = recordModel.locationFirst
            saveReadingProgressLocally()
        }
    }
}

