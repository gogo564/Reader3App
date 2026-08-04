//
//  DZMReadController.swift
//  DZMeBookRead
//
//  Created by dengzemiao on 2019/4/17.
//  Copyright © 2019年 DZM. All rights reserved.
//

import UIKit
import AVFoundation

class DZMReadController: DZMViewController,DZMReadMenuDelegate,UIPageViewControllerDelegate,UIPageViewControllerDataSource,DZMCoverControllerDelegate,DZMReadContentViewDelegate,DZMReadCatalogViewDelegate,DZMReadMarkViewDelegate,DZMRMTTSViewDelegate,AVSpeechSynthesizerDelegate {

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

    // MARK: -- TTS

    private let TTS_VOICE_NAME_KEY = "tts_voice_name"
    private let TTS_VOICE_LANG_KEY = "tts_voice_lang"

    private var ttsSynthesizer: AVSpeechSynthesizer = {
        AVSpeechSynthesizer()
    }()
    private var ttsVoice: AVSpeechSynthesisVoice?
    private var ttsSpeed: Float = 1.0
    private var ttsPlaying: Bool = false
    private var ttsHasStarted: Bool = false
    private var ttsStopped: Bool = false
    private var ttsPausePage: Int = -1
    private var ttsQueueID: Int = 0
    private var ttsSegments: [TTSSegment] = []
    private var ttsSegmentIndex: Int = 0
    private var ttsUtteranceSegment: [ObjectIdentifier: Int] = [:]
    private var lastSavedProgressKey: String = ""

    private struct TTSSegment {
        let range: NSRange
        let page: Int
    }

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        ttsSynthesizer.delegate = self

        if let savedName = UserDefaults.standard.string(forKey: TTS_VOICE_NAME_KEY),
           let savedLang = UserDefaults.standard.string(forKey: TTS_VOICE_LANG_KEY) {
            ttsVoice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.name == savedName && $0.language == savedLang })
        }
        
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

        ttsStopped = true
        ttsPausePage = -1
        ttsQueueID += 1
        ttsUtteranceSegment.removeAll()
        if ttsSynthesizer.isPaused {
            ttsSynthesizer.continueSpeaking()
        }
        ttsSynthesizer.stopSpeaking(at: .immediate)
        ttsPlaying = false
        ttsHasStarted = false
    }
    
    /// 进度保存: 本地为准。位置未变化返回 false（不再触发服务器上传）
    @discardableResult
    func saveReadingProgressLocally() -> Bool {
        guard let rm = readModel?.recordModel, let chapterID = rm.chapterModel?.id else { return false }
        let bookUrl = readModel.bookID ?? ""
        let index = chapterID.intValue
        let pos = rm.locationFirst?.intValue ?? 0
        let key = "\(index):\(pos)"
        guard key != lastSavedProgressKey else { return false }
        lastSavedProgressKey = key
        CacheManager.shared.updateBookProgress(bookUrl: bookUrl, bookName: readModel.bookName ?? "", index: index, chapterTitle: rm.chapterName ?? "", time: Int64(Date().timeIntervalSince1970 * 1000), pos: pos)
        return true
    }

    /// 进度保存: 本地为准 + 服务器只保留章节。仅当阅读位置发生变化时才上传，减少请求数
    func saveReadingProgress() {
        guard saveReadingProgressLocally() else { return }
        guard let rm = readModel?.recordModel, let chapterID = rm.chapterModel?.id else { return }
        let bookUrl = readModel.bookID ?? ""
        let index = chapterID.intValue
        let title = rm.chapterName ?? ""
        let bookName = readModel.bookName ?? ""
        let time = Int64(Date().timeIntervalSince1970 * 1000)

        if NetworkMonitor.shared.isConnected {
            guard !AppState.shared.isDeleted(bookUrl: bookUrl) else { return }
            Task {
                if let cached = CacheManager.shared.findCachedBook(bookUrl: bookUrl) {
                    _ = try? await NetworkService.shared.saveBook(cached.withChapterProgress(index: index, title: title, time: time))
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

    /// 点击朗读
    func readMenuClickTTS(readMenu: DZMReadMenu!) {
        readMenu.showTopView(isShow: false)
        readMenu.showBottomView(isShow: false)
        readMenu.showTTSView(isShow: true)
        readMenu.ttsView.chapterName = readModel.recordModel.chapterModel.name ?? ""
        if let voice = ttsVoice {
            readMenu.ttsView.setVoiceName(voice.name)
        }
    }

    /// 点击换源
    func readMenuClickSwitchSource(readMenu: DZMReadMenu!) {
        readMenu.showMenu(isShow: false)
        let bookName = readModel.bookName ?? ""
        toast("正在搜索书源...")

        Task { [weak self] in
            guard let self = self else { return }
            guard let sources = try? await NetworkService.shared.getBookSources(simple: true) else {
                await MainActor.run { self.toast("获取书源列表失败") }
                return
            }

            let maxResults = 200
            let perTimeout: UInt64 = 8_000_000_000
            let totalTimeout: TimeInterval = 15
            let bookNameLower = bookName.trimmingCharacters(in: .whitespaces).lowercased()

            let picker = SourcePickerViewController(maxResults: maxResults, totalTimeout: totalTimeout) { [weak self] result in
                self?.switchToSource(result: result)
            }
            picker.modalPresentationStyle = .overFullScreen
            await MainActor.run { self.present(picker, animated: false) }

            let validSources = sources.filter { !($0.bookSourceUrl?.isEmpty ?? true) }

            await withTaskGroup(of: (SearchResult?, TimeInterval, String?).self) { group in
                for src in validSources {
                    guard let srcUrl = src.bookSourceUrl else { continue }
                    group.addTask {
                        let t = Task<(SearchResult?, TimeInterval, String?), Error> {
                            let start = CFAbsoluteTimeGetCurrent()
                            let all = try await NetworkService.shared.searchOnSource(bookName: bookName, sourceUrl: srcUrl, timeout: 8)
                            let elapsed = CFAbsoluteTimeGetCurrent() - start
                            for r in all {
                                guard r.name.trimmingCharacters(in: .whitespaces).lowercased().contains(bookNameLower) else { continue }
                                return (r, elapsed, srcUrl)
                            }
                            return (nil, 0, srcUrl)
                        }
                        Task {
                            try await Task.sleep(nanoseconds: perTimeout)
                            t.cancel()
                        }
                        guard let (r, e, u) = try? await t.value, let rr = r else { return (nil, 0, srcUrl) }
                        return (rr, e, u)
                    }
                }

                for await (result, elapsed, srcUrl) in group {
                    guard let r = result, let origin = r.origin ?? srcUrl else { continue }
                    var stop = false
                    await MainActor.run {
                        picker.addResult(r, latency: elapsed, origin: origin)
                        stop = picker.shouldStop
                    }
                    if stop {
                        group.cancelAll()
                        break
                    }
                }
            }

            await MainActor.run {
                if picker.resultCount == 0 {
                    picker.dismiss(animated: true) { self.toast("未找到可用书源") }
                }
            }
        }
    }

    private func switchToSource(result: SearchResult) {
        let newUrl = result.bookUrl
        let srcUrl = result.origin
        let bookName = readModel.bookName ?? ""
        let author = bookAuthor
        let currentIndex = readModel.recordModel.chapterModel.id?.intValue ?? 0
        Task { [weak self] in
            guard let self = self else { return }
            do {
                await MainActor.run { self.toast("正在切换...") }
                let chapters = try await NetworkService.shared.getChapterList(bookUrl: newUrl, bookSourceUrl: srcUrl)
                let safeIndex = currentIndex < chapters.count ? currentIndex : 0
                let rawContent = try await NetworkService.shared.getBookContent(bookUrl: newUrl, index: safeIndex)
                let content = DZMReadParser.contentTypesetting(content: rawContent)
                CacheManager.shared.cacheChapter(bookUrl: newUrl, index: safeIndex, content: rawContent)
                CacheManager.shared.cacheChapters(bookUrl: newUrl, chapters: chapters)
                CacheManager.shared.setCachedTotal(newUrl, total: chapters.count)
                let newBook = Book(bookUrl: newUrl, name: bookName, author: author,
                                  coverUrl: result.coverUrl, origin: result.origin, originName: result.originName,
                                  intro: result.intro, latestChapterTitle: result.latestChapterTitle,
                                  type: result.type, tocUrl: result.tocUrl)
                do { try await NetworkService.shared.deleteBook(bookUrl: readModel.bookID) } catch { print("deleteBook failed: \(error)") }
                CacheManager.shared.clearCache(bookUrl: readModel.bookID)
                try? await NetworkService.shared.saveBook(newBook)
                await MainActor.run {
                    if var cached = CacheManager.shared.getCachedBookshelf() {
                        if let idx = cached.firstIndex(where: { $0.bookUrl == readModel.bookID }) {
                            cached[idx] = newBook
                        } else {
                            cached.append(newBook)
                        }
                        CacheManager.shared.cacheBookshelf(cached)
                    } else {
                        CacheManager.shared.cacheBookshelf([newBook])
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
                    self.toast("已切换到「\(result.originName ?? "新源")」")
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

    // MARK: -- DZMRMTTSViewDelegate

    func ttsViewDidTapClose(_ ttsView: DZMRMTTSView) {
        stopTTS()
        readMenu.showTTSView(isShow: false)
        readMenu.showMenu(isShow: true)
    }

    func ttsViewDidTapPlayPause(_ ttsView: DZMRMTTSView) {
        if ttsPlaying {
            pauseTTS()
        } else if ttsHasStarted && readModel.recordModel.page.intValue == ttsPausePage {
            resumeTTS()
        } else {
            startTTS()
        }
    }

    func ttsViewDidTapPrevious(_ ttsView: DZMRMTTSView) {
        guard !readModel.recordModel.isFirstChapter else { return }
        let prevID = readModel.recordModel.chapterModel.previousChapterID!
        navigateToChapter(chapterID: prevID) { [weak self] in
            self?.startTTS()
        }
    }

    func ttsViewDidTapNext(_ ttsView: DZMRMTTSView) {
        guard !readModel.recordModel.isLastChapter else { return }
        let nextID = readModel.recordModel.chapterModel.nextChapterID!
        navigateToChapter(chapterID: nextID) { [weak self] in
            self?.startTTS()
        }
    }

    func ttsView(_ ttsView: DZMRMTTSView, didChangeSpeed speed: Float) {
        ttsSpeed = speed
        guard ttsPlaying || ttsHasStarted else { return }
        if ttsPlaying {
            restartTTS()
        } else {
            stopTTS()
        }
    }

    func ttsView(_ ttsView: DZMRMTTSView, didSelectVoice voice: AVSpeechSynthesisVoice) {
        ttsVoice = voice
        UserDefaults.standard.set(voice.name, forKey: TTS_VOICE_NAME_KEY)
        UserDefaults.standard.set(voice.language, forKey: TTS_VOICE_LANG_KEY)
        guard ttsPlaying || ttsHasStarted else { return }
        if ttsPlaying {
            restartTTS()
        } else {
            stopTTS()
        }
    }

    // MARK: -- TTS 控制

    private func startTTS(base: Int? = nil) {
        guard let chapter = readModel.recordModel.chapterModel,
              let full = chapter.fullContent,
              !full.string.isEmpty else { return }

        ttsSynthesizer.stopSpeaking(at: .immediate)

        let titleLen = chapter.fullName.utf16.count
        let location = readModel.recordModel.locationFirst?.intValue ?? 0
        let b = base ?? min(max(location, titleLen), full.string.utf16.count)
        guard b < full.string.utf16.count else { return }
        ttsPausePage = readModel.recordModel.page.intValue

        let segments = buildTTSSegments(chapter: chapter, from: b)
        guard !segments.isEmpty else { return }

        ttsQueueID += 1
        ttsUtteranceSegment.removeAll()
        ttsSegments = segments
        ttsSegmentIndex = 0
        ttsStopped = false
        currentDisplayController?.setTTSSpokenRange(nil)

        let nsFull = full.string as NSString
        for (i, seg) in segments.enumerated() {
            let text = nsFull.substring(with: seg.range)
            guard !text.isEmpty else { continue }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = ttsVoice ?? AVSpeechSynthesisVoice(language: "zh-CN")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * ttsSpeed
            utterance.volume = 1.0
            ttsUtteranceSegment[ObjectIdentifier(utterance)] = i
            ttsSynthesizer.speak(utterance)
        }

        ttsPlaying = true
        ttsHasStarted = true

        readMenu?.ttsView?.isPlaying = true
        readMenu?.ttsView?.chapterName = chapter.name ?? ""

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// 按"句子/段落 + 页码"拆分朗读段, 一段不跨页, 整段高亮;
    /// 优先断在句末标点: 窗口内没有就扩大范围继续找, 实在没有才退而断在最后一个逗号, 避免硬切在词语中间
    private func buildTTSSegments(chapter: DZMReadChapterModel, from base: Int) -> [TTSSegment] {
        guard let full = chapter.fullContent, !full.string.isEmpty,
              let pageModels = chapter.pageModels, !pageModels.isEmpty else { return [] }
        let ns = full.string as NSString
        let total = ns.length
        let maxLen = 45
        let hardCap = 120
        let enderChars: Set<UniChar> = [0x3002, 0xFF01, 0xFF1F, 0x2026, 0xFF1B, 0x3B, 0x21, 0x3F, 0x0A]
        let softChars: Set<UniChar> = [0xFF0C, 0x2C]

        var result: [TTSSegment] = []
        for (pageIdx, pm) in pageModels.enumerated() {
            let pageStart = max(pm.range.location, base)
            let pageEnd = min(pm.range.location + pm.range.length, total)
            if pageStart >= pageEnd { continue }
            var s = pageStart
            while s < pageEnd {
                let softLimit = min(s + maxLen, pageEnd)
                var lastEnder = -1
                var lastSoft = -1
                var j = s
                while j < softLimit {
                    let ch = ns.character(at: j)
                    if enderChars.contains(ch) { lastEnder = j + 1 }
                    if softChars.contains(ch) { lastSoft = j + 1 }
                    j += 1
                }
                var e: Int
                if lastEnder > 0 {
                    e = lastEnder
                } else if softLimit < pageEnd {
                    let hardLimit = min(s + hardCap, pageEnd)
                    var farEnder = -1
                    var k = softLimit
                    while k < hardLimit {
                        if enderChars.contains(ns.character(at: k)) { farEnder = k + 1 }
                        k += 1
                    }
                    if farEnder > 0 {
                        e = farEnder
                    } else if lastSoft > 0 {
                        e = lastSoft
                    } else {
                        e = hardLimit
                    }
                } else if lastSoft > 0 {
                    e = lastSoft
                } else {
                    e = pageEnd
                }
                let len = e - s
                if len > 0 {
                    result.append(TTSSegment(range: NSRange(location: s, length: len), page: pageIdx))
                }
                s = e
            }
        }
        return result
    }

    private func pauseTTS() {
        ttsPausePage = readModel.recordModel.page.intValue
        ttsSynthesizer.pauseSpeaking(at: .word)
        ttsPlaying = false
        readMenu.ttsView.isPlaying = false
    }

    private func resumeTTS() {
        ttsSynthesizer.continueSpeaking()
        ttsPlaying = true
        readMenu.ttsView.isPlaying = true
    }

    private func stopTTS() {
        ttsStopped = true
        ttsPausePage = -1
        ttsQueueID += 1
        ttsUtteranceSegment.removeAll()
        if ttsSynthesizer.isPaused {
            ttsSynthesizer.continueSpeaking()
        }
        ttsSynthesizer.stopSpeaking(at: .immediate)
        ttsPlaying = false
        ttsHasStarted = false
        currentDisplayController?.setTTSSpokenRange(nil)
        readMenu?.ttsView?.isPlaying = false
    }

    private func restartTTS() {
        guard !ttsSegments.isEmpty else {
            startTTS()
            return
        }
        let idx = min(max(ttsSegmentIndex, 0), ttsSegments.count - 1)
        startTTS(base: ttsSegments[idx].range.location)
    }

    // MARK: -- AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard !ttsStopped else { return }
        guard let segIdx = ttsUtteranceSegment[ObjectIdentifier(utterance)], segIdx < ttsSegments.count else { return }
        ttsSegmentIndex = segIdx
        let seg = ttsSegments[segIdx]
        ttsTurnPage(to: seg.page)

        guard let pageModel = currentDisplayController?.recordModel.pageModel else { return }
        let local = seg.range.location - pageModel.range.location
        if local >= 0 {
            let length = min(seg.range.length, max(0, pageModel.content.length - local))
            if length > 0 {
                currentDisplayController?.setTTSSpokenRange(NSRange(location: local, length: length))
            } else {
                currentDisplayController?.setTTSSpokenRange(nil)
            }
        } else {
            currentDisplayController?.setTTSSpokenRange(nil)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !ttsStopped else { return }
        guard let segIdx = ttsUtteranceSegment[ObjectIdentifier(utterance)] else { return }
        if segIdx == ttsSegmentIndex {
            currentDisplayController?.setTTSSpokenRange(nil)
        }
        guard segIdx == ttsSegments.count - 1 else { return }
        guard !readModel.recordModel.isLastChapter else {
            ttsPlaying = false
            currentDisplayController?.setTTSSpokenRange(nil)
            readMenu?.ttsView?.isPlaying = false
            return
        }
        let nextID = readModel.recordModel.chapterModel.nextChapterID!
        navigateToChapter(chapterID: nextID) { [weak self] in
            guard let self = self, !self.ttsStopped else { return }
            self.startTTS()
        }
    }

    private func ttsTurnPage(to page: Int) {
        guard let cm = readModel.recordModel.chapterModel else { return }
        let target = min(max(page, 0), max(cm.pageCount.intValue - 1, 0))
        let current = readModel.recordModel.page.intValue
        guard target != current else { return }

        if DZMReadConfigure.shared().effectType == .scroll {
            scrollController?.scrollToTTSLocation(page: target)
            return
        }

        let newRecord = readModel.recordModel.copyModel()
        newRecord.page = NSNumber(value: target)
        updateReadRecord(recordModel: newRecord)
        guard let vc = GetReadViewController(recordModel: newRecord) else { return }
        currentDisplayController = vc
        setViewController(displayController: vc, isAbove: target < current, animated: false)
    }

    private func navigateToChapter(chapterID: NSNumber, completion: @escaping () -> Void) {
        let index = chapterID.intValue
        let bookUrl = readModel.bookID ?? ""

        GoToChapter(chapterID: chapterID)
        readMenu.topView.checkForMark()
        readMenu.bottomView.progressView.reloadProgress()

        if let cm = readModel.recordModel.chapterModel, cm.id == chapterID, let c = cm.content, !c.isEmpty {
            completion()
            return
        }

        toast("正在加载章节...")
        Task {
            do {
                let raw = try await chapterContent?(bookUrl, index) ?? ""
                let content = DZMReadParser.contentTypesetting(content: raw)
                await MainActor.run {
                    readModel.recordModel.chapterModel.content = content
                    completion()
                }
            } catch {
                await MainActor.run { self.toast("加载失败") }
            }
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
        
        ttsStopped = true
        ttsPausePage = -1
        ttsQueueID += 1
        ttsUtteranceSegment.removeAll()
        if ttsSynthesizer.isPaused {
            ttsSynthesizer.continueSpeaking()
        }
        ttsSynthesizer.stopSpeaking(at: .immediate)
        ttsSynthesizer.delegate = nil
        ttsPlaying = false
        ttsHasStarted = false
        
        // 移除阅读长按视图监控
        DZM_READ_NOTIFICATION_REMOVE(target: self)
        
        // 清理阅读控制器
        clearPageController()
    }
}

