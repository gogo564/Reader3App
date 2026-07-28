//
//  DZMReadController.swift
//  DZMeBookRead
//
//  Created by dengzemiao on 2019/4/17.
//  Copyright © 2019年 DZM. All rights reserved.
//

import UIKit

class DZMReadController: DZMViewController,DZMReadMenuDelegate,UIPageViewControllerDelegate,UIPageViewControllerDataSource,DZMCoverControllerDelegate,DZMReadContentViewDelegate,DZMReadCatalogViewDelegate,DZMReadMarkViewDelegate {

    var readModel: DZMReadModel!
    var chapterList: ((_ bookUrl: String) async throws -> [Chapter])?
    var chapterContent: ((_ bookUrl: String, _ index: Int) async throws -> String)?

    var contentView: DZMReadContentView!
    var leftView: DZMReadLeftView!
    var readMenu: DZMReadMenu!
    var pageViewController: UIPageViewController!
    var scrollController: DZMReadViewScrollController!
    var coverController: DZMCoverController!
    var currentDisplayController: DZMReadViewController?
    var tempNumber: NSInteger = 1
    var catalogChapters: [Chapter] = []
    var bookAuthor: String?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // 初始化书籍阅读记录
        updateReadRecord(recordModel: readModel.recordModel)
        
        // 初始化菜单
        readMenu = DZMReadMenu(vc: self, delegate: self)
        
        // 背景颜色
        view.backgroundColor = DZMReadConfigure.shared().bgColor
        
        // 初始化控制器
        creatPageController(displayController: GetCurrentReadViewController(isUpdateFont: true))
        
        // 监控阅读长按视图通知
        monitorReadLongPressView()

        startAutoSaveTimer()
    }

    private var autoSaveTimer: Timer?

    private func startAutoSaveTimer() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.saveReadingProgress()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        UIApplication.shared.setStatusBarStyle(.lightContent, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        
        UIApplication.shared.setStatusBarStyle(.default, animated: true)

        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        
        saveReadingProgress()
    }
    
    private func saveReadingProgress() {
        guard let rm = readModel?.recordModel, let chapterID = rm.chapterModel?.id else { return }
        let bookUrl = readModel.bookID ?? ""
        let index = chapterID.intValue
        let title = rm.chapterName ?? ""
        let bookName = readModel.bookName ?? ""
        let time = Int64(Date().timeIntervalSince1970 * 1000)

        CacheManager.shared.updateBookProgress(bookUrl: bookUrl, bookName: bookName, index: index, chapterTitle: title, time: time)

        if NetworkMonitor.shared.isConnected {
            Task {
                if let cached = CacheManager.shared.findCachedBook(bookUrl: bookUrl) {
                    var book = cached.withProgress(index: index, title: title, time: time)
                    _ = try? await NetworkService.shared.saveBook(book)
                } else {
                    let book = Book(bookUrl: bookUrl, name: bookName, author: nil, durChapterTitle: title, durChapterIndex: index, durChapterTime: time)
                    _ = try? await NetworkService.shared.saveBook(book)
                }
            }
        } else {
            let payload = (try? JSONSerialization.data(withJSONObject: ["bookUrl": bookUrl, "bookName": bookName, "durChapterIndex": index, "durChapterTitle": title, "durChapterTime": time])) ?? Data()
            SyncQueue.shared.enqueue(type: .saveProgress, bookUrl: bookUrl, payload: payload)
        }
    }

    override func addSubviews() {
        
        super.addSubviews()
        
        // 目录侧滑栏
        leftView = DZMReadLeftView()
        leftView.catalogView.readModel = readModel
        leftView.catalogView.delegate = self
        leftView.markView.readModel = readModel
        leftView.markView.delegate = self
        leftView.isHidden = true
        view.addSubview(leftView)
        leftView.frame = CGRect(x: -DZM_READ_LEFT_VIEW_WIDTH, y: 0, width: DZM_READ_LEFT_VIEW_WIDTH, height: DZM_READ_LEFT_VIEW_HEIGHT)
        
        // 阅读视图
        contentView = DZMReadContentView()
        contentView.delegate = self
        view.addSubview(contentView)
        contentView.frame = CGRect(x: 0, y: 0, width: DZM_READ_CONTENT_VIEW_WIDTH, height: DZM_READ_CONTENT_VIEW_HEIGHT)
    }
    
    // MARK: 监控阅读长按视图通知
    
    // 监控阅读长按视图通知
    private func monitorReadLongPressView() {
        
        if DZMReadConfigure.shared().openLongPress {
            
            DZM_READ_NOTIFICATION_MONITOR(target: self, action: #selector(longPressViewNotification(notification:)))
        }
    }
    
    // 处理通知
    @objc private func longPressViewNotification(notification:Notification) {
        
        // 获得状态
        let info = notification.userInfo
        
        // 隐藏菜单
        readMenu.showMenu(isShow: false)
        
        // 解析状态
        if info != nil && info!.keys.contains(DZM_READ_KEY_LONG_PRESS_VIEW) {
            
            let isOpen = info![DZM_READ_KEY_LONG_PRESS_VIEW] as! NSNumber
            
            coverController?.gestureRecognizerEnabled = isOpen.boolValue
            
            pageViewController?.gestureRecognizerEnabled = isOpen.boolValue
            
            readMenu.singleTap.isEnabled = isOpen.boolValue
        }
    }
    
    
    // MARK: DZMReadCatalogViewDelegate
    
    /// 章节目录选中章节
    func catalogViewClickChapter(catalogView: DZMReadCatalogView, chapterListModel: DZMReadChapterListModel) {
        
        showLeftView(isShow: false)
        
        contentView.showCover(isShow: false)
        
        if readModel.recordModel.chapterModel.id == chapterListModel.id { return }
        
        GoToChapter(chapterID: chapterListModel.id)
    }
    
    // MARK: DZMReadMarkViewDelegate
    
    /// 书签列表选中书签
    func markViewClickMark(markView: DZMReadMarkView, markModel: DZMReadMarkModel) {
        
        showLeftView(isShow: false)
        
        contentView.showCover(isShow: false)
        
        GoToChapter(chapterID: markModel.chapterID, location: markModel.location.intValue)
    }
    
    
    // MARK: DZMReadContentViewDelegate
    
    /// 点击遮罩
    func contentViewClickCover(contentView: DZMReadContentView) {
        
        showLeftView(isShow: false)
    }
    
    
    // MARK: DZMReadMenuDelegate
    
    /// 菜单将要显示
    func readMenuWillDisplay(readMenu: DZMReadMenu!) {
        
        // 检查当前内容是否包含书签
        readMenu.topView.checkForMark()
        
        // 刷新阅读进度
        readMenu.bottomView.progressView.reloadProgress()
    }
    
    /// 点击返回
    func readMenuClickBack(readMenu: DZMReadMenu!) {
        
        // 清空所有阅读缓存
        // DZMKeyedArchiver.clear()
        
        // 清空指定书籍缓存
        // DZMKeyedArchiver.remove(folderName: bookID)
        
        // 清空坐标
        DZM_READ_RECORD_CURRENT_CHAPTER_LOCATION = nil
        
        // 返回
        navigationController?.popViewController(animated: true)
    }
    
    /// 点击书签
    func readMenuClickMark(readMenu: DZMReadMenu!, topView: DZMRMTopView!, markButton: UIButton!) {
        
        markButton.isSelected = !markButton.isSelected
        
        if markButton.isSelected { readModel.insetMark()
            
        }else{ _ = readModel.removeMark() }
        
        topView.updateMarkButton()
    }
    
    /// 点击目录
    func readMenuClickCatalogue(readMenu:DZMReadMenu!) {
        
        showLeftView(isShow: true)
        
        contentView.showCover(isShow: true)
        
        readMenu.showMenu(isShow: false)
    }
    
    /// 点击日夜间
    func readMenuClickDayAndNight(readMenu:DZMReadMenu!) {
        let isNight = DZMUserDefaults.bool(DZM_READ_KEY_MODE_DAY_NIGHT)
        let config = DZMReadConfigure.shared()
        if isNight {
            config.bgColorIndex = NSNumber(value: 4)
        } else {
            config.bgColorIndex = NSNumber(value: 1)
        }
        config.save()
        view.backgroundColor = config.bgColor
        creatPageController(displayController: GetCurrentReadViewController())
    }
    
    /// 点击上一章
    func readMenuClickPreviousChapter(readMenu: DZMReadMenu!) {
        
        if readModel.recordModel.isFirstChapter {
            
            DZMLog("已经是第一章了")
            
        }else{
            
            GoToChapter(chapterID: readModel.recordModel.chapterModel.previousChapterID)
            
            // 检查当前内容是否包含书签
            readMenu.topView.checkForMark()
            
            // 刷新阅读进度
            readMenu.bottomView.progressView.reloadProgress()
        }
    }
    
    /// 点击下一章
    func readMenuClickNextChapter(readMenu: DZMReadMenu!) {
        
        if readModel.recordModel.isLastChapter {
            
            DZMLog("已经是最后一章了")
            
        }else{
            
            GoToChapter(chapterID: readModel.recordModel.chapterModel.nextChapterID)
    
            // 检查当前内容是否包含书签
            readMenu.topView.checkForMark()
            
            // 刷新阅读进度
            readMenu.bottomView.progressView.reloadProgress()
        }
    }
    
    /// 拖拽阅读记录
    func readMenuDraggingProgress(readMenu: DZMReadMenu!, toPage: NSInteger) {
        
        if readModel.recordModel.page.intValue != toPage{
            
            readModel.recordModel.page = NSNumber(value: toPage)
            
            creatPageController(displayController: GetCurrentReadViewController())
            
            // 检查当前内容是否包含书签
            readMenu.topView.checkForMark()
        }
    }
    
    /// 拖拽章节进度(总文章进度,网络文章也可以使用)
    func readMenuDraggingProgress(readMenu: DZMReadMenu!, toChapterID: NSNumber, toPage: NSInteger) {
        
        // 不是当前阅读记录章节
        if toChapterID != readModel!.recordModel.chapterModel.id {
            
            GoToChapter(chapterID: toChapterID, toPage: toPage)
            
            // 检查当前内容是否包含书签
            readMenu.topView.checkForMark()
        }
    }
    
    /// 切换进度显示(分页 || 总进度)
    func readMenuClickDisplayProgress(readMenu: DZMReadMenu) {
        
        creatPageController(displayController: GetCurrentReadViewController())
    }
    
    /// 点击切换背景颜色
    func readMenuClickBGColor(readMenu: DZMReadMenu) {
        
        // 切换背景颜色可以根据需求判断修改目录背景颜色,文字颜色等等(目前放在showLeftView方法中,leftView将要出现的时候处理)
        // leftView.updateUI()
        
        view.backgroundColor = DZMReadConfigure.shared().bgColor
        
        creatPageController(displayController: GetCurrentReadViewController())
    }
    
    /// 点击切换字体
    func readMenuClickFont(readMenu: DZMReadMenu) {
        
        creatPageController(displayController: GetCurrentReadViewController(isUpdateFont: true))
    }
    
    /// 点击切换字体大小
    func readMenuClickFontSize(readMenu: DZMReadMenu) {
        
        creatPageController(displayController: GetCurrentReadViewController(isUpdateFont: true))
    }
    
    /// 点击切换间距
    func readMenuClickSpacing(readMenu: DZMReadMenu) {
        
        creatPageController(displayController: GetCurrentReadViewController(isUpdateFont: true))
    }
    
    /// 点击切换翻页效果
    func readMenuClickEffect(readMenu: DZMReadMenu) {
        
        creatPageController(displayController: GetCurrentReadViewController())
    }

    /// 点击换源
    func readMenuClickSwitchSource(readMenu: DZMReadMenu!) {
        readMenu.showMenu(isShow: false)
        Task { [weak self] in
            guard let self = self else { return }
            guard let sources = try? await NetworkService.shared.getBookSources(simple: true) else {
                await MainActor.run { self.toast("获取书源失败") }
                return
            }
            let alert = UIAlertController(title: "选择书源", message: nil, preferredStyle: .actionSheet)
            for src in sources {
                guard let name = src.bookSourceName, !name.isEmpty else { continue }
                alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                    self?.switchToSource(src)
                })
            }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            if let popover = alert.popoverPresentationController {
                popover.sourceView = readMenu.bottomView
                popover.sourceRect = readMenu.bottomView.bounds
            }
            await MainActor.run { present(alert, animated: true) }
        }
    }

    private func switchToSource(_ source: BookSource) {
        guard let srcUrl = source.bookSourceUrl, !srcUrl.isEmpty else {
            toast("该书源无效")
            return
        }
        let bookName = readModel.bookName ?? ""
        let author = bookAuthor
        Task { [weak self] in
            guard let self = self else { return }
            do {
                await MainActor.run { self.toast("正在搜索...") }
                let results = try await NetworkService.shared.searchOnSource(bookName: bookName, sourceUrl: srcUrl)
                var match: SearchResult?
                for r in results {
                    guard r.name == bookName else { continue }
                    if let a = author, !a.isEmpty, r.author != a { continue }
                    match = r
                    break
                }
                guard let m = match else {
                    await MainActor.run { self.toast("未在本书源找到「\(bookName)」") }
                    return
                }
                let newUrl = m.bookUrl
                guard !newUrl.isEmpty else {
                    await MainActor.run { self.toast("该书源不可用") }
                    return
                }
                let chapters = try await NetworkService.shared.getChapterList(bookUrl: newUrl, bookSourceUrl: srcUrl)
                let safeIndex: Int
                let content: String
                let newBook: Book
                (safeIndex, content, newBook) = try await {
                    let currentIndex = readModel.recordModel.chapterModel.id?.intValue ?? 0
                    let si = currentIndex < chapters.count ? currentIndex : 0
                    let rawContent = try await NetworkService.shared.getBookContent(bookUrl: newUrl, index: si)
                    let ct = DZMReadParser.contentTypesetting(content: rawContent)
                    CacheManager.shared.cacheChapter(bookUrl: newUrl, index: si, content: rawContent)
                    CacheManager.shared.cacheChapters(bookUrl: newUrl, chapters: chapters)
                    CacheManager.shared.setCachedTotal(newUrl, total: chapters.count)
                    let nb = Book(bookUrl: newUrl, name: bookName, author: author,
                                  coverUrl: m.coverUrl, origin: m.origin, originName: m.originName,
                                  intro: m.intro, latestChapterTitle: m.latestChapterTitle,
                                  type: m.type, tocUrl: m.tocUrl)
                    return (si, ct, nb)
                }()
                try? await NetworkService.shared.saveBook(newBook)
                await MainActor.run {
                    if var cached = CacheManager.shared.getCachedBookshelf() {
                        if let idx = cached.firstIndex(where: { $0.bookUrl == readModel.bookID }) {
                            cached[idx] = newBook
                            CacheManager.shared.cacheBookshelf(cached)
                        }
                    }
                    catalogChapters = chapters
                    readModel.bookID = newUrl
                    readModel.chapterListModels.removeAll()
                    for (i, ch) in chapters.enumerated() {
                        let lm = DZMReadChapterListModel()
                        lm.id = NSNumber(value: i)
                        lm.name = ch.title
                        lm.bookID = newUrl
                        readModel.chapterListModels.append(lm)
                    }
                    let cm = DZMReadChapterModel()
                    cm.bookID = newUrl
                    cm.id = NSNumber(value: safeIndex)
                    cm.name = chapters[safe: safeIndex]?.title ?? "开始阅读"
                    cm.content = content
                    cm.priority = NSNumber(value: safeIndex)
                    if safeIndex > 0 { cm.previousChapterID = NSNumber(value: safeIndex - 1) }
                    else { cm.previousChapterID = DZM_READ_NO_MORE_CHAPTER }
                    if safeIndex < chapters.count - 1 { cm.nextChapterID = NSNumber(value: safeIndex + 1) }
                    else { cm.nextChapterID = DZM_READ_NO_MORE_CHAPTER }
                    cm.updateFont()
                    let rm = DZMReadRecordModel()
                    rm.bookID = newUrl
                    rm.chapterModel = cm
                    readModel.recordModel = rm
                    readMenu.topView.updateMarkButton()
                    readMenu.bottomView.progressView.reloadProgress()
                    creatPageController(displayController: GetCurrentReadViewController())
                    self.toast("已切换到「\(source.bookSourceName ?? "新源")」")
                }
            } catch {
                await MainActor.run { self.toast("换源失败: \(error.localizedDescription)") }
            }
        }
    }

    private func toast(_ msg: String) {
        let lbl = UILabel()
        lbl.text = msg
        lbl.textColor = .white
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        lbl.textAlignment = .center
        lbl.font = .systemFont(ofSize: 15)
        lbl.sizeToFit()
        lbl.frame.size.width += 32
        lbl.frame.size.height += 16
        lbl.layer.cornerRadius = 8
        lbl.clipsToBounds = true
        lbl.center = CGPoint(x: view.center.x, y: view.center.y - 80)
        lbl.alpha = 0
        view.addSubview(lbl)
        UIView.animate(withDuration: 0.25) { lbl.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.25) { lbl.alpha = 0 } completion: { _ in lbl.removeFromSuperview() }
        }
    }

    // MARK: 展示动画
    
    /// 辅视图展示
    func showLeftView(isShow:Bool, completion:DZMAnimationCompletion? = nil) {
     
        if isShow { // leftView 将要显示
            
            // 刷新UI 
            leftView.updateUI()
            
            // 滚动到阅读记录
            leftView.catalogView.scrollRecord()
            
            // 允许显示
            leftView.isHidden = false
        }
        
        UIView.animate(withDuration: DZM_READ_AD_TIME, delay: 0, options: .curveEaseOut, animations: { [weak self] () in
            
            if isShow {
                
                self?.leftView.frame.origin = CGPoint.zero
                
                self?.contentView.frame.origin = CGPoint(x: DZM_READ_LEFT_VIEW_WIDTH, y: 0)
                
            }else{
                
                self?.leftView.frame.origin = CGPoint(x: -DZM_READ_LEFT_VIEW_WIDTH, y: 0)
                
                self?.contentView.frame.origin = CGPoint.zero
            }
            
        }) { [weak self] (isOK) in
            
            if !isShow { self?.leftView.isHidden = true }
            
            completion?()
        }
    }
    
    deinit {
        
        // 移除阅读长按视图监控
        DZM_READ_NOTIFICATION_REMOVE(target: self)
        
        // 清理阅读控制器
        clearPageController()
    }
}
