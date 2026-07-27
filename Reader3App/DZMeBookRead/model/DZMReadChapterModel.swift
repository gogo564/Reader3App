import UIKit

class DZMReadChapterModel: NSObject {
    var bookID: String!
    var id: NSNumber!
    var previousChapterID: NSNumber!
    var nextChapterID: NSNumber!
    var name: String!
    var content: String!
    var priority: NSNumber!
    var pageCount: NSNumber! = NSNumber(value: 0)
    var pageModels: [DZMReadPageModel]! = []

    var isFirstChapter: Bool! { previousChapterID == DZM_READ_NO_MORE_CHAPTER }
    var isLastChapter: Bool! { nextChapterID == DZM_READ_NO_MORE_CHAPTER }
    var fullName: String! { DZM_READ_CHAPTER_NAME(name) }
    var fullContent: NSAttributedString!
    var pageTotalHeight: CGFloat {
        pageModels.reduce(0) { $0 + $1.contentSize.height + $1.headTypeHeight }
    }

    private var attributes: [NSAttributedString.Key: Any]! = [:]

    func updateFont() {
        let temp = DZMReadConfigure.shared().attributes(isTitle: false, isPageing: true)
        if !NSDictionary(dictionary: attributes).isEqual(to: temp) {
            attributes = temp
            fullContent = fullContentAttrString()
            pageModels = DZMReadParser.pageing(attrString: fullContent, rect: CGRect(origin: .zero, size: DZM_READ_VIEW_RECT.size))
            pageCount = NSNumber(value: pageModels.count)
        }
    }

    private func fullContentAttrString() -> NSMutableAttributedString {
        let title = NSMutableAttributedString(string: fullName, attributes: DZMReadConfigure.shared().attributes(isTitle: true))
        let body = NSMutableAttributedString(string: content, attributes: DZMReadConfigure.shared().attributes(isTitle: false))
        title.append(body)
        return title
    }

    private subscript(page: NSInteger) -> DZMReadPageModel? {
        guard !pageModels.isEmpty, page >= 0, page < pageModels.count else { return nil }
        return pageModels[page]
    }

    func contentString(page: NSInteger) -> String { self[page]?.content.string ?? "" }
    func contentAttributedString(page: NSInteger) -> NSAttributedString { self[page]?.showContent ?? NSAttributedString() }
    func locationFirst(page: NSInteger) -> NSNumber { self[page].map { NSNumber(value: $0.range.location) } ?? NSNumber(value: 0) }
    func locationLast(page: NSInteger) -> NSNumber {
        guard let r = self[page]?.range else { return NSNumber(value: 0) }
        return NSNumber(value: r.location + r.length)
    }
    func locationCenter(page: NSInteger) -> NSNumber {
        guard let r = self[page]?.range else { return NSNumber(value: 0) }
        return NSNumber(value: (r.location + (r.location + r.length) / 2))
    }
    func page(location: NSInteger) -> NSNumber {
        for (i, m) in pageModels.enumerated() {
            if location < m.range.location + m.range.length { return NSNumber(value: i) }
        }
        return NSNumber(value: 0)
    }
}
