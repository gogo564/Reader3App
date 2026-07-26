import UIKit

class DZMReadViewScrollController: DZMViewController, UITableViewDelegate, UITableViewDataSource {

    weak var vc: DZMReadController!
    private var topView: DZMReadViewStatusTopView!
    private var tableView: DZMTableView!
    private var bottomView: DZMReadViewStatusBottomView!
    private var chapterIDs: [NSNumber] = []
    private var loadChapterIDs: [NSNumber] = []
    private var chapterModels: [String: DZMReadChapterModel] = [:]
    private var scrollPoint: CGPoint!
    private var isScrollUp: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        let cm = vc.readModel.recordModel.chapterModel
        chapterIDs.append(cm.id)
        chapterModels[cm.id.stringValue] = cm
        reloadProgress()
        let page = min(Int(truncating: vc.readModel.recordModel.page), cm.pageCount.intValue - 1)
        if page >= 0 {
            tableView.scrollToRow(at: IndexPath(row: page, section: 0), at: .top, animated: false)
        }
    }

    override func addSubviews() {
        super.addSubviews()
        let readRect = DZM_READ_RECT!
        topView = DZMReadViewStatusTopView()
        topView.bookName.text = vc.readModel.bookName
        topView.chapterName.text = vc.readModel.recordModel.chapterModel.name
        view.addSubview(topView)
        topView.frame = CGRect(x: readRect.minX, y: readRect.minY, width: readRect.width, height: DZM_READ_STATUS_TOP_VIEW_HEIGHT)
        tableView = DZMTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        tableView.frame = DZM_READ_VIEW_RECT
        bottomView = DZMReadViewStatusBottomView()
        view.addSubview(bottomView)
        bottomView.frame = CGRect(x: readRect.minX, y: readRect.maxY - DZM_READ_STATUS_BOTTOM_VIEW_HEIGHT, width: readRect.width, height: DZM_READ_STATUS_BOTTOM_VIEW_HEIGHT)
    }

    func numberOfSections(in tableView: UITableView) -> Int { chapterIDs.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let chapterModel = GetChapterModel(chapterID: chapterIDs[section])
        return chapterModel?.pageCount?.intValue ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let chapterModel = GetChapterModel(chapterID: chapterIDs[indexPath.section])
        let pageModel = chapterModel!.pageModels[indexPath.row]
        if pageModel.isHomePage {
            let cell = DZMReadHomeViewCell.cell(tableView)
            cell.homeView.readModel = vc.readModel
            return cell
        } else {
            let cell = DZMReadViewCell.cell(tableView)
            cell.pageModel = pageModel
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let chapterModel = GetChapterModel(chapterID: chapterIDs[indexPath.section])
        return chapterModel!.pageModels[indexPath.row].cellHeight
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { DZM_SPACE_MIN_HEIGHT }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let chapterModel = chapterModels[chapterIDs[section].stringValue]
        preloadingPrevious(chapterModel)
        preloadingNext(chapterModel)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row != 0 { return }
        let chapterModel = GetChapterModel(chapterID: chapterIDs[indexPath.section])
        if chapterModel!.pageModels[indexPath.row].isHomePage {
            topView?.isHidden = true
            bottomView?.isHidden = true
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row != 0 { return }
        let chapterModel = GetChapterModel(chapterID: chapterIDs[indexPath.section])
        if chapterModel!.pageModels[indexPath.row].isHomePage {
            topView?.isHidden = false
            bottomView?.isHidden = false
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        vc.readMenu.showMenu(isShow: false)
        isScrollUp = true
        scrollPoint = .zero
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        updateReadRecord(isRollingUp: isScrollUp)
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        updateReadRecord(isRollingUp: isScrollUp)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateReadRecord(isRollingUp: isScrollUp)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollPoint != nil else { return }
        let point = scrollView.panGestureRecognizer.translation(in: scrollView)
        isScrollUp = point.y < scrollPoint.y
        scrollPoint = point
    }

    private func updateReadRecord(isRollingUp: Bool) {
        let indexPaths = tableView.indexPathsForVisibleRows
        DispatchQueue.global().async { [weak self] in
            guard let self = self, let ip = indexPaths, !ip.isEmpty else { return }
            let indexPath: IndexPath = isRollingUp ? ip.last! : ip.first!
            let chapterID = self.chapterIDs[indexPath.section]
            let chapterModel = self.GetChapterModel(chapterID: chapterID)
            self.vc.readModel.recordModel.modify(chapterModel: chapterModel, page: indexPath.row)
            DZM_READ_RECORD_CURRENT_CHAPTER_LOCATION = self.vc.readModel.recordModel.locationFirst
            DispatchQueue.main.async {
                self.topView.chapterName.text = chapterModel?.name
                self.reloadProgress()
            }
        }
    }

    private func reloadProgress() {
        if DZMReadConfigure.shared().progressType == .total {
            let progress: Float = DZM_READ_TOTAL_PROGRESS(readModel: vc.readModel, recordModel: vc.readModel.recordModel)
            bottomView.progress.text = DZM_READ_TOTAL_PROGRESS_STRING(progress: progress)
        } else {
            bottomView.progress.text = "\(vc.readModel.recordModel.page.intValue + 1)/\(vc.readModel.recordModel.chapterModel!.pageCount.intValue)"
        }
    }

    private func GetChapterModel(chapterID: NSNumber) -> DZMReadChapterModel? {
        if let m = chapterModels[chapterID.stringValue] { return m }
        return nil
    }

    private func preloadingPrevious(_ chapterModel: DZMReadChapterModel!) {
        guard let cm = chapterModel, let chapterID = cm.previousChapterID, !cm.isFirstChapter,
              !loadChapterIDs.contains(chapterID), !chapterIDs.contains(chapterID) else { return }
        loadChapterIDs.append(chapterID)
        let bookID = cm.bookID!
        let index = chapterID.intValue
        preloadChapter(bookID: bookID, chapterID: chapterID, index: index) { [weak self] temp in
            guard let self = self else { return }
            self.chapterModels[chapterID.stringValue] = temp
            let previousIndex = max(0, self.chapterIDs.firstIndex(of: cm.id)!)
            let loadIndex = self.loadChapterIDs.firstIndex(of: chapterID)!
            self.chapterIDs.insert(chapterID, at: previousIndex)
            self.loadChapterIDs.remove(at: loadIndex)
            self.tableView.reloadData()
            self.tableView.contentOffset = CGPoint(x: 0, y: self.tableView.contentOffset.y + temp.pageTotalHeight)
        }
    }

    private func preloadingNext(_ chapterModel: DZMReadChapterModel!) {
        guard let cm = chapterModel, let chapterID = cm.nextChapterID, !cm.isLastChapter,
              !loadChapterIDs.contains(chapterID), !chapterIDs.contains(chapterID) else { return }
        loadChapterIDs.append(chapterID)
        let bookID = cm.bookID!
        let index = chapterID.intValue
        preloadChapter(bookID: bookID, chapterID: chapterID, index: index) { [weak self] temp in
            guard let self = self else { return }
            self.chapterModels[chapterID.stringValue] = temp
            let nextIndex = self.chapterIDs.firstIndex(of: cm.id)! + 1
            let loadIndex = self.loadChapterIDs.firstIndex(of: chapterID)!
            self.chapterIDs.insert(chapterID, at: nextIndex)
            self.loadChapterIDs.remove(at: loadIndex)
            self.tableView.insertSections(IndexSet(integer: nextIndex), with: .none)
        }
    }

    private func preloadChapter(bookID: String, chapterID: NSNumber, index: Int, completion: @escaping (DZMReadChapterModel) -> Void) {
        Task {
            do {
                let content = try await vc.chapterContent?(bookID, index) ?? ""
                let title = vc.catalogChapters[safe: index]?.title ?? ""
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
                if index < vc.catalogChapters.count - 1 {
                    chapterModel.nextChapterID = NSNumber(value: index + 1)
                } else {
                    chapterModel.nextChapterID = DZM_READ_NO_MORE_CHAPTER
                }
                chapterModel.updateFont()
                await MainActor.run { completion(chapterModel) }
            } catch {}
        }
    }
}
