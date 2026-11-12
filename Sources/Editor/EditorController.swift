import AppKit
import SwiftUI

struct OutlineItem: Identifiable, Equatable {
    /// 標題在文件中的字元位置。
    let id: Int
    let title: String
    let level: Int
}

struct ExportFailure: Equatable {
    let title: String
    let message: String
}

struct DiagramEditRequest: Identifiable {
    let id = UUID()
    let attachment: DiagramAttachment
    /// 剛插入的流程圖；取消編輯時要一併移除。
    let isNew: Bool
}

/// 一份文件的編輯狀態：擁有文字檢視，提供工具列與選單呼叫的所有指令。
@MainActor
final class EditorController: NSObject, ObservableObject {
    let scrollView: NSScrollView
    let textView: MeadTextView

    @Published private(set) var currentStyle: BlockStyle = .title
    @Published private(set) var isBold = false
    @Published private(set) var isItalic = false
    @Published private(set) var isStrikethrough = false
    @Published private(set) var selectionIsAttachment = false
    @Published private(set) var selectedAttachment: ObjectIdentifier?
    @Published private(set) var outline: [OutlineItem] = []
    @Published private(set) var currentOutlineID: Int?
    @Published var diagramBeingEdited: DiagramEditRequest?
    @Published var isExporting = false
    @Published var printPreview: PrintPreviewItem?
    /// 顯示 Markdown 原始格式。這是給懂語法的人檢查用的，預設關閉。
    @Published private(set) var isSourceMode = false
    @Published var exportFailure: ExportFailure?
    /// 檔名（不含副檔名），用來當 PDF 的預設檔名。
    var documentName = "未命名"

    /// 文件結尾的空段落沒有任何字元可以掛屬性，它的樣式另外記在這裡。
    private var trailingSemantic: [NSAttributedString.Key: Any]? = [.meadBlock: BlockStyle.title.rawValue]
    private var outlineRefresh: DispatchWorkItem?
    private var linkPopover: NSPopover?
    private var nextCodeGroup = 100_000

    private var storage: NSTextStorage { textView.textStorage! }

    private static let blockKeys: [NSAttributedString.Key] = [.meadBlock, .meadIndent, .meadCheck, .meadCodeLanguage, .meadCodeGroup]
    private static let inlineKeys: [NSAttributedString.Key] = [.meadBold, .meadItalic, .meadStrike, .meadInlineCode]

    private let snapshot: MarkdownSnapshot
    private var snapshotIsScheduled = false
    private var pendingRestyle: NSRange?
    private var isRestyling = false

    init(markdown: String, snapshot: MarkdownSnapshot = MarkdownSnapshot("")) {
        (scrollView, textView) = MeadTextView.makeScrollable()
        self.snapshot = snapshot
        super.init()
        textView.editor = self

        let content = MarkdownImporter.attributedString(from: markdown)
        if content.length > 0 {
            storage.setAttributedString(content)
            trailingSemantic = nil
        }
        storage.delegate = self
        textView.textLayoutManager?.delegate = self
        textView.delegate = self
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        syncTypingAttributes()
        refreshOutline()
    }

    var markdown: String {
        isSourceMode ? sourceTextView.string : MarkdownExporter.markdown(from: storage)
    }

    // MARK: Markdown 原始格式

    private var sourceAtEntry = ""
    private lazy var sourceDelegate = SourceTextDelegate { [weak self] in self?.scheduleSnapshot() }

    private(set) lazy var sourceTextView: NSTextView = {
        let view = NSTextView()
        view.isRichText = false
        view.allowsUndo = true
        view.usesFindBar = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        view.textColor = OKMPalette.text
        view.backgroundColor = Theme.page
        view.insertionPointColor = OKMPalette.primary
        view.selectedTextAttributes = [.backgroundColor: Theme.selection]
        view.textContainerInset = NSSize(width: 40, height: 32)
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.delegate = sourceDelegate
        view.setAccessibilityLabel("Markdown 原始格式")
        return view
    }()

    private(set) lazy var sourceScrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.page
        scrollView.documentView = sourceTextView
        return scrollView
    }()

    func toggleSourceMode() {
        if isSourceMode {
            let edited = sourceTextView.string
            isSourceMode = false
            if edited != sourceAtEntry { replaceContent(withMarkdown: edited) }
            DispatchQueue.main.async { [textView] in textView.window?.makeFirstResponder(textView) }
        } else {
            sourceAtEntry = MarkdownExporter.markdown(from: storage)
            sourceTextView.string = sourceAtEntry
            isSourceMode = true
            DispatchQueue.main.async { [sourceTextView] in sourceTextView.window?.makeFirstResponder(sourceTextView) }
        }
    }

    /// 把整份文件換成這段 Markdown 的內容（可復原）。
    private func replaceContent(withMarkdown markdown: String) {
        let content = MarkdownImporter.attributedString(from: markdown)
        let full = NSRange(location: 0, length: storage.length)
        edit(full, replacement: content.string, actionName: "編輯原始格式") { storage in
            storage.replaceCharacters(in: full, with: content)
        }
        trailingSemantic = content.length == 0 ? [.meadBlock: BlockStyle.title.rawValue] : nil
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        syncTypingAttributes()
        refreshOutline()
    }

    /// 內容一有變動，就在這一輪事件處理結束時更新存檔用的快照。
    /// 存檔指令與自動儲存都是之後的事件，所以輪到它們時快照一定是最新的。
    private func scheduleSnapshot() {
        guard !snapshotIsScheduled else { return }
        snapshotIsScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.snapshotIsScheduled = false
            self.snapshot.value = self.markdown
        }
    }

    /// 立刻更新快照（測試用）。
    func flushSnapshot() {
        snapshot.value = markdown
    }

    // MARK: 內部工具

    private var nsString: NSString { storage.string as NSString }

    private func paragraphRange(at location: Int) -> NSRange {
        nsString.paragraphRange(for: NSRange(location: min(location, storage.length), length: 0))
    }

    /// 游標是否在文件結尾那個沒有字元的空段落。
    private func isTrailingEmptyParagraph(_ location: Int) -> Bool {
        location == storage.length && (storage.length == 0 || nsString.character(at: storage.length - 1) == 0x0A)
    }

    private func attachment(at location: Int) -> NSTextAttachment? {
        guard location < storage.length else { return nil }
        return storage.attribute(.attachment, at: location, effectiveRange: nil) as? NSTextAttachment
    }

    private func paragraphHoldsAttachment(_ range: NSRange) -> Bool {
        var found = false
        storage.enumerateAttribute(.attachment, in: range) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }

    func range(of target: NSTextAttachment) -> NSRange? {
        var result: NSRange?
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
            if value as AnyObject === target { result = range; stop.pointee = true }
        }
        return result
    }

    /// 所有改動文字儲存區的操作都經過這裡，才會進入復原堆疊並通知排版。
    private func edit(_ range: NSRange, replacement: String? = nil, actionName: String, _ change: (NSTextStorage) -> Void) {
        guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
        storage.beginEditing()
        change(storage)
        storage.endEditing()
        textView.didChangeText()
        textView.undoManager?.setActionName(actionName)
    }

    private func textRange(for range: NSRange) -> NSTextRange? {
        guard let content = textView.textLayoutManager?.textContentManager,
              let start = content.location(content.documentRange.location, offsetBy: range.location),
              let end = content.location(start, offsetBy: range.length) else { return nil }
        return NSTextRange(location: start, end: end)
    }

    private func characterOffset(of location: any NSTextLocation) -> Int {
        guard let content = textView.textLayoutManager?.textContentManager else { return 0 }
        return content.offset(from: content.documentRange.location, to: location)
    }

    private func invalidateLayout(_ range: NSRange) {
        guard let textRange = textRange(for: range) else { return }
        textView.textLayoutManager?.invalidateLayout(for: textRange)
        textView.needsDisplay = true
        textView.repositionStyleTagSoon()
    }

    /// 結尾空行的清單記號畫在上一段的片段裡；它的樣式一變，上一段就要重新排版。
    private func invalidateTrailingLine() {
        guard storage.length > 0, nsString.character(at: storage.length - 1) == 0x0A else { return }
        invalidateLayout(paragraphRange(at: storage.length - 1))
    }

    /// 清單編號與程式碼區塊的圓角取決於相鄰段落，文字變動後整組要重畫。
    private func invalidateGroup(around location: Int) {
        guard storage.length > 0 else { return }
        var range = paragraphRange(at: min(location, storage.length - 1))
        func grouped(_ index: Int) -> Bool {
            let style = storage.blockStyle(at: index)
            return style.isList || style == .code
        }
        guard grouped(range.location) || (range.location > 0 && grouped(range.location - 1)) else { return }
        while range.location > 0, grouped(range.location - 1) {
            range = NSUnionRange(range, paragraphRange(at: range.location - 1))
        }
        while NSMaxRange(range) < storage.length, grouped(NSMaxRange(range)) {
            range = NSUnionRange(range, paragraphRange(at: NSMaxRange(range)))
        }
        invalidateLayout(range)
    }

    // MARK: 選取狀態

    private func semanticAttributes(forCaretAt location: Int) -> [NSAttributedString.Key: Any] {
        if isTrailingEmptyParagraph(location) {
            if let trailingSemantic { return trailingSemantic }
            guard storage.length > 0 else { return [.meadBlock: BlockStyle.body.rawValue] }
            return storage.attributes(at: storage.length - 1, effectiveRange: nil).filter { Self.blockKeys.contains($0.key) }
        }
        let paragraph = paragraphRange(at: location)
        let source = location > paragraph.location ? location - 1 : paragraph.location
        var attributes = storage.attributes(at: source, effectiveRange: nil)
        let keepsInline = attributes[.attachment] == nil
        attributes = attributes.filter { Self.blockKeys.contains($0.key) || (keepsInline && Self.inlineKeys.contains($0.key)) }
        // 游標在連結中間才延續連結；停在連結尾端時接著打的字不屬於連結。
        if location > paragraph.location, location < storage.length,
           let before = storage.attribute(.link, at: location - 1, effectiveRange: nil) as? URL,
           let after = storage.attribute(.link, at: location, effectiveRange: nil) as? URL, before == after {
            attributes[.link] = before
        }
        return attributes
    }

    private func applyTypingAttributes(_ semantic: [NSAttributedString.Key: Any]) {
        let style = BlockStyle(rawValue: semantic[.meadBlock] as? String ?? "") ?? .body
        var attributes = semantic
        attributes.merge(Styling.displayAttributes(style: style, semantic: semantic)) { _, new in new }
        attributes[.paragraphStyle] = Theme.paragraphStyle(for: style, indent: semantic[.meadIndent] as? Int ?? 0)
        textView.typingAttributes = attributes
    }

    private func syncTypingAttributes() {
        let selection = textView.selectedRange()
        let semantic = semanticAttributes(forCaretAt: selection.location)
        if selection.length == 0 { applyTypingAttributes(semantic) }

        currentStyle = BlockStyle(rawValue: semantic[.meadBlock] as? String ?? "") ?? .body
        let probe = selection.length > 0 ? storage.attributes(at: selection.location, effectiveRange: nil) : semantic
        isBold = probe[.meadBold] as? Bool == true
        isItalic = probe[.meadItalic] as? Bool == true
        isStrikethrough = probe[.meadStrike] as? Bool == true

        let selected = selection.length == 1 ? attachment(at: selection.location) : nil
        selectedAttachment = selected.map(ObjectIdentifier.init)
        selectionIsAttachment = selected != nil
            || (!isTrailingEmptyParagraph(selection.location) && paragraphHoldsAttachment(paragraphRange(at: selection.location)))
        currentOutlineID = outline.last { $0.id <= selection.location }?.id
        textView.updateStyleTag(animated: true)
    }

    // MARK: 段落樣式

    func setBlockStyle(_ style: BlockStyle) {
        guard !isSourceMode else { return }
        let selection = textView.selectedRange()
        if selection.length == 0, isTrailingEmptyParagraph(selection.location) {
            var semantic = semanticAttributes(forCaretAt: selection.location)
            semantic[.meadBlock] = style.rawValue
            if !style.isList { semantic[.meadIndent] = nil }
            semantic[.meadCheck] = style == .todo ? false : nil
            trailingSemantic = semantic
            invalidateTrailingLine()
            syncTypingAttributes()
            textView.refreshPlaceholder()
            return
        }
        let range = nsString.paragraphRange(for: selection)
        edit(range, actionName: "更改樣式") { storage in
            var location = range.location
            while location < NSMaxRange(range) {
                let paragraph = self.paragraphRange(at: location)
                location = NSMaxRange(paragraph)
                guard !self.paragraphHoldsAttachment(paragraph) else { continue }
                storage.addAttribute(.meadBlock, value: style.rawValue, range: paragraph)
                storage.removeAttribute(.meadCheck, range: paragraph)
                if !style.isList { storage.removeAttribute(.meadIndent, range: paragraph) }
            }
        }
        invalidateGroup(around: range.location)
        syncTypingAttributes()
        scheduleOutlineRefresh()
    }

    /// 工具列的清單按鈕：已經是該種清單就改回內文。
    func toggleList(_ style: BlockStyle) {
        setBlockStyle(currentStyle == style ? .body : style)
    }

    func changeListIndent(by delta: Int) {
        guard !isSourceMode else { return }
        let selection = textView.selectedRange()
        if selection.length == 0, isTrailingEmptyParagraph(selection.location) {
            var semantic = semanticAttributes(forCaretAt: selection.location)
            guard BlockStyle(rawValue: semantic[.meadBlock] as? String ?? "")?.isList == true else { return }
            semantic[.meadIndent] = allowedIndent((semantic[.meadIndent] as? Int ?? 0) + delta, before: storage.length)
            trailingSemantic = semantic
            invalidateTrailingLine()
            syncTypingAttributes()
            return
        }
        let range = nsString.paragraphRange(for: selection)
        guard storage.blockStyle(at: range.location).isList else { return }
        edit(range, actionName: delta > 0 ? "增加縮排" : "減少縮排") { storage in
            var location = range.location
            while location < NSMaxRange(range) {
                let paragraph = self.paragraphRange(at: location)
                location = NSMaxRange(paragraph)
                guard storage.blockStyle(at: paragraph.location).isList else { continue }
                let target = self.allowedIndent(storage.indentLevel(at: paragraph.location) + delta, before: paragraph.location)
                storage.addAttribute(.meadIndent, value: target, range: paragraph)
            }
        }
        invalidateGroup(around: range.location)
        syncTypingAttributes()
    }

    /// 子項目最多比上一個清單項目深一層，否則 Markdown 會把它當成程式碼。
    private func allowedIndent(_ proposed: Int, before location: Int) -> Int {
        var limit = 0
        if location > 0, storage.blockStyle(at: location - 1).isList {
            limit = storage.indentLevel(at: location - 1) + 1
        }
        return min(max(proposed, 0), min(limit, 4))
    }

    // MARK: 文字格式

    func toggleBold() { toggleInline(.meadBold, actionName: "粗體") }
    func toggleItalic() { toggleInline(.meadItalic, actionName: "斜體") }
    func toggleStrikethrough() { toggleInline(.meadStrike, actionName: "刪除線") }

    private func toggleInline(_ key: NSAttributedString.Key, actionName: String) {
        let selection = textView.selectedRange()
        guard !selectionIsAttachment, !isSourceMode else { return }
        if selection.length == 0 {
            var semantic = textView.typingAttributes.filter {
                Self.blockKeys.contains($0.key) || Self.inlineKeys.contains($0.key) || $0.key == .link
            }
            semantic[key] = semantic[key] as? Bool == true ? nil : true
            applyTypingAttributes(semantic)
            isBold = semantic[.meadBold] as? Bool == true
            isItalic = semantic[.meadItalic] as? Bool == true
            isStrikethrough = semantic[.meadStrike] as? Bool == true
            return
        }
        var allOn = true
        storage.enumerateAttribute(key, in: selection) { value, _, stop in
            if value as? Bool != true { allOn = false; stop.pointee = true }
        }
        edit(selection, actionName: actionName) { storage in
            if allOn {
                storage.removeAttribute(key, range: selection)
            } else {
                storage.addAttribute(key, value: true, range: selection)
            }
        }
        syncTypingAttributes()
    }

    // MARK: 按鍵行為

    /// 在空的清單項目或空的引言按 Return：離開清單，而不是再多一個空項目。
    func handleReturn() -> Bool {
        let selection = textView.selectedRange()
        guard selection.length == 0 else { return false }
        let style = currentStyle
        guard style.isList || style == .quote else { return false }
        let isEmpty: Bool
        if isTrailingEmptyParagraph(selection.location) {
            isEmpty = true
        } else {
            let paragraph = paragraphRange(at: selection.location)
            isEmpty = paragraph.length == 1 && nsString.character(at: paragraph.location) == 0x0A
        }
        guard isEmpty else { return false }
        if style.isList, (semanticAttributes(forCaretAt: selection.location)[.meadIndent] as? Int ?? 0) > 0 {
            changeListIndent(by: -1)
        } else {
            setBlockStyle(.body)
        }
        return true
    }

    /// 標題後面按 Return 接著是內文；清單則延續同一種清單。
    func didInsertNewline() {
        let caret = textView.selectedRange().location
        guard caret > 0 else { return }
        var semantic = storage.attributes(at: caret - 1, effectiveRange: nil).filter { Self.blockKeys.contains($0.key) }
        let previousStyle = BlockStyle(rawValue: semantic[.meadBlock] as? String ?? "") ?? .body
        let paragraph = paragraphRange(at: caret)
        let newParagraphIsEmpty = isTrailingEmptyParagraph(caret)
            || (paragraph.length == 1 && nsString.character(at: paragraph.location) == 0x0A)
        guard newParagraphIsEmpty else { return }

        semantic[.meadBlock] = previousStyle.styleAfterReturn.rawValue
        // 新的待辦項目一律從未勾選開始。
        semantic[.meadCheck] = previousStyle == .todo ? false : nil
        if isTrailingEmptyParagraph(caret) {
            trailingSemantic = semantic
            invalidateTrailingLine()
        } else {
            storage.beginEditing()
            storage.addAttributes(semantic, range: paragraph)
            storage.endEditing()
            flushRestyle()
        }
        invalidateGroup(around: caret - 1)
        syncTypingAttributes()
    }

    /// 在段落開頭按 Delete：先把樣式退回內文（或減少縮排），再按一次才會和上一段合併。
    func handleDeleteAtParagraphStart() -> Bool {
        let selection = textView.selectedRange()
        guard selection.length == 0 else { return false }
        let caret = selection.location
        let atStart = isTrailingEmptyParagraph(caret) || paragraphRange(at: caret).location == caret
        guard atStart else { return false }

        if currentStyle != .body {
            if currentStyle.isList, (semanticAttributes(forCaretAt: caret)[.meadIndent] as? Int ?? 0) > 0 {
                changeListIndent(by: -1)
            } else {
                setBlockStyle(.body)
            }
            return true
        }
        // 上一段是表格或流程圖時先選取它，避免文字被併進同一段。
        if caret >= 2, let previous = attachment(at: caret - 2) as? BlockAttachment, range(of: previous) != nil {
            textView.setSelectedRange(NSRange(location: caret - 2, length: 1))
            return true
        }
        return false
    }

    /// 表格、流程圖各自獨佔一段。游標停在這種段落時，先開一個新段落再輸入。
    func moveCaretOffAttachmentParagraph() {
        let selection = textView.selectedRange()
        guard selection.length == 0, !isTrailingEmptyParagraph(selection.location) else { return }
        let paragraph = paragraphRange(at: selection.location)
        guard paragraphHoldsAttachment(paragraph) else { return }
        let before = attachment(at: selection.location) != nil
        let newline = NSAttributedString(string: "\n", attributes: [.meadBlock: BlockStyle.body.rawValue])
        edit(NSRange(location: selection.location, length: 0), replacement: "\n", actionName: "輸入") { storage in
            storage.insert(newline, at: selection.location)
        }
        textView.setSelectedRange(NSRange(location: before ? selection.location : selection.location + 1, length: 0))
    }

    func toggleCheckbox(at point: NSPoint) -> Bool {
        guard let hit = textView.layoutFragment(at: point), let fragment = hit.fragment as? MeadLayoutFragment,
              let rect = fragment.checkboxRect, rect.insetBy(dx: -3, dy: -3).contains(hit.local) else { return false }
        let paragraph = paragraphRange(at: characterOffset(of: fragment.rangeInElement.location))
        guard let checked = storage.attribute(.meadCheck, at: paragraph.location, effectiveRange: nil) as? Bool else { return false }
        edit(paragraph, actionName: checked ? "取消勾選" : "勾選") { storage in
            storage.addAttribute(.meadCheck, value: !checked, range: paragraph)
        }
        invalidateLayout(paragraph)
        return true
    }

    // MARK: 貼上

    func paste(_ text: String, isMarkdown: Bool) {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        guard isMarkdown || Self.looksLikeMarkdown(normalized) else {
            textView.insertText(normalized, replacementRange: textView.selectedRange())
            return
        }
        let content = MarkdownImporter.attributedString(from: normalized)
        // 只有一段內文時當成行內文字貼上，沿用游標所在段落的樣式。
        if !content.string.contains("\n"), content.blockStyle(at: 0) == .body, content.length > 0,
           content.attribute(.attachment, at: 0, effectiveRange: nil) == nil {
            let block = textView.typingAttributes.filter { Self.blockKeys.contains($0.key) }
            content.addAttributes(block, range: NSRange(location: 0, length: content.length))
        }
        textView.insertText(content, replacementRange: textView.selectedRange())
        scheduleOutlineRefresh()
    }

    /// 從 AI 工具或其他編輯器複製來的文字常帶著 Markdown 記號；辨識出來就轉成樣式，不讓記號留在畫面上。
    static func looksLikeMarkdown(_ text: String) -> Bool {
        let blockPattern = #"(?m)^(#{1,6} \S|[-*+] \S|\d+\. \S|> \S|\|.+\|\s*$|```)"#
        let inlinePattern = #"\*\*[^*\n]+\*\*|\[[^\]\n]+\]\([^)\s]+\)"#
        return text.range(of: blockPattern, options: .regularExpression) != nil
            || text.range(of: inlinePattern, options: .regularExpression) != nil
    }

    // MARK: 插入區塊

    func insertTable() {
        let model = TableModel.blank(rows: 3, columns: 3)
        insertBlock(TableAttachment(model: model), actionName: "插入表格")
    }

    func insertDivider() {
        insertBlock(DividerAttachment(), actionName: "插入分隔線")
    }

    func insertDiagram() {
        guard !isSourceMode else { return }
        let attachment = DiagramAttachment(model: DiagramModel(source: Flowchart.starter.mermaid))
        insertBlock(attachment, actionName: "插入流程圖")
        diagramBeingEdited = DiagramEditRequest(attachment: attachment, isNew: true)
    }

    private func insertBlock(_ attachment: NSTextAttachment, actionName: String) {
        guard !isSourceMode else { return }
        let selection = textView.selectedRange()
        let body: [NSAttributedString.Key: Any] = [.meadBlock: BlockStyle.body.rawValue]
        let insertion = NSMutableAttributedString()
        var location = selection.location
        var caretOffset = 2

        if isTrailingEmptyParagraph(selection.location) {
            insertion.append(MarkdownImporter.paragraph(for: attachment))
        } else {
            let paragraph = paragraphRange(at: selection.location)
            let hasTerminator = nsString.character(at: NSMaxRange(paragraph) - 1) == 0x0A
            let contentLength = paragraph.length - (hasTerminator ? 1 : 0)
            if contentLength == 0 {
                // 空段落直接換成區塊，原本的換行字元留在區塊後面。
                location = paragraph.location
                insertion.append(MarkdownImporter.paragraph(for: attachment))
            } else {
                location = paragraph.location + contentLength
                insertion.append(NSAttributedString(string: "\n", attributes: body))
                insertion.append(NSAttributedString(attachment: attachment))
                insertion.addAttributes(body, range: NSRange(location: 0, length: insertion.length))
                if !hasTerminator { insertion.append(NSAttributedString(string: "\n", attributes: body)) }
                caretOffset = 3
            }
        }
        edit(NSRange(location: location, length: 0), replacement: insertion.string, actionName: actionName) { storage in
            storage.insert(insertion, at: location)
        }
        trailingSemantic = body
        textView.setSelectedRange(NSRange(location: min(location + caretOffset, storage.length), length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: insertion.length))
    }

    func deleteBlock(_ attachment: NSTextAttachment) {
        guard var range = range(of: attachment) else { return }
        if NSMaxRange(range) < storage.length, nsString.character(at: NSMaxRange(range)) == 0x0A { range.length += 1 }
        edit(range, replacement: "", actionName: "刪除") { storage in
            storage.deleteCharacters(in: range)
        }
        textView.setSelectedRange(NSRange(location: min(range.location, storage.length), length: 0))
        textView.window?.makeFirstResponder(textView)
    }

    func selectBlock(_ attachment: NSTextAttachment) {
        guard let range = range(of: attachment) else { return }
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(range)
    }

    /// 表格或流程圖的內容變了：登記復原，並讓排版重新量高度。
    func blockDidChange(_ attachment: NSTextAttachment, actionName: String, undo: @escaping @MainActor () -> Void) {
        if let undoManager = textView.undoManager {
            undoManager.registerUndo(withTarget: self) { _ in
                MainActor.assumeIsolated { undo() }
            }
            undoManager.setActionName(actionName)
        }
        relayoutBlock(attachment)
        scheduleSnapshot()
    }

    func relayoutBlock(_ attachment: NSTextAttachment) {
        guard let range = range(of: attachment) else { return }
        invalidateLayout(range)
    }

    func editDiagram(_ attachment: DiagramAttachment) {
        diagramBeingEdited = DiagramEditRequest(attachment: attachment, isNew: false)
    }

    func finishDiagramEdit(_ request: DiagramEditRequest, source: String?) {
        diagramBeingEdited = nil
        if let source {
            request.attachment.model.update(source)
        } else if request.isNew {
            deleteBlock(request.attachment)
        }
        textView.window?.makeFirstResponder(textView)
    }

    // MARK: 連結

    func editLink() {
        guard !selectionIsAttachment, !isSourceMode else { return }
        var range = textView.selectedRange()
        var existing: URL?
        let probe = range.length > 0 ? range.location : max(range.location - 1, 0)
        if probe < storage.length {
            var linkRange = NSRange()
            if let url = storage.attribute(.link, at: probe, longestEffectiveRange: &linkRange,
                                           in: NSRange(location: 0, length: storage.length)) as? URL,
               range.length == 0 || NSIntersectionRange(linkRange, range).length > 0 {
                existing = url
                range = NSUnionRange(range, linkRange)
            }
        }
        let text = nsString.substring(with: range)
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: LinkEditor(
            text: text, address: existing?.absoluteString ?? "", isExisting: existing != nil,
            onCommit: { [weak self, weak popover] text, url in
                popover?.close()
                self?.applyLink(url, text: text, to: range)
            },
            onRemove: { [weak self, weak popover] in
                popover?.close()
                self?.removeLink(in: range)
            },
            onOpen: { url in NSWorkspace.shared.open(url) }
        ))
        linkPopover = popover
        popover.show(relativeTo: anchorRect(for: range), of: textView, preferredEdge: .maxY)
    }

    private func anchorRect(for range: NSRange) -> NSRect {
        let screenRect = textView.firstRect(forCharacterRange: range, actualRange: nil)
        guard let window = textView.window, screenRect != .zero else { return textView.visibleRect.insetBy(dx: 200, dy: 100) }
        var rect = textView.convert(window.convertFromScreen(screenRect), from: nil)
        rect.size.width = max(rect.width, 2)
        return rect
    }

    private func applyLink(_ url: URL, text: String, to range: NSRange) {
        let label = text.isEmpty ? url.absoluteString : text
        var attributes = range.length > 0
            ? storage.attributes(at: range.location, effectiveRange: nil)
            : textView.typingAttributes
        attributes[.link] = url
        attributes[.attachment] = nil
        let replacement = NSAttributedString(string: label, attributes: attributes)
        edit(range, replacement: label, actionName: "連結") { storage in
            storage.replaceCharacters(in: range, with: replacement)
        }
        textView.setSelectedRange(NSRange(location: range.location + (label as NSString).length, length: 0))
        textView.window?.makeFirstResponder(textView)
    }

    private func removeLink(in range: NSRange) {
        edit(range, actionName: "移除連結") { storage in
            storage.removeAttribute(.link, range: range)
        }
        textView.window?.makeFirstResponder(textView)
    }

    // MARK: 大綱

    private func scheduleOutlineRefresh() {
        outlineRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshOutline() }
        outlineRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func refreshOutline() {
        var items: [OutlineItem] = []
        var location = 0
        while location < storage.length {
            let paragraph = paragraphRange(at: location)
            location = NSMaxRange(paragraph)
            let style = storage.blockStyle(at: paragraph.location)
            guard let level = style.headingLevel else { continue }
            let title = nsString.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { items.append(OutlineItem(id: paragraph.location, title: title, level: level)) }
        }
        if items != outline { outline = items }
        currentOutlineID = items.last { $0.id <= textView.selectedRange().location }?.id
    }

    func jump(to item: OutlineItem) {
        guard item.id <= storage.length, !isSourceMode else { return }
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: item.id, length: 0))
        textView.scrollRangeToVisible(paragraphRange(at: item.id))
    }

    // MARK: 轉成 PDF 與列印

    func exportPDF() {
        guard let window = scrollView.window ?? sourceScrollView.window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = documentName + ".pdf"
        panel.prompt = "轉成 PDF"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.isExporting = true
            Task {
                defer { self.isExporting = false }
                do {
                    try await PDFExporter.export(markdown: self.markdown, to: url, window: window)
                } catch {
                    self.exportFailure = ExportFailure(
                        title: "無法轉成 PDF",
                        message: "請確認儲存位置可以寫入後再試一次。（\(error.localizedDescription)）"
                    )
                }
            }
        }
    }

    /// 先產生和「轉成 PDF」完全相同的結果放在暫存區，再用預覽視窗攤開來看。
    func showPrintPreview() {
        guard let window = scrollView.window ?? sourceScrollView.window else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OKM-Mead-preview-\(UUID().uuidString).pdf")
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                try await PDFExporter.export(markdown: markdown, to: url, window: window)
                printPreview = PrintPreviewItem(url: url)
            } catch {
                exportFailure = ExportFailure(title: "無法預覽列印", message: "請再試一次。（\(error.localizedDescription)）")
            }
        }
    }

    func printDocument() {
        guard let window = scrollView.window ?? sourceScrollView.window else { return }
        Task {
            do {
                try await PDFExporter.print(markdown: markdown, window: window)
            } catch {
                exportFailure = ExportFailure(title: "無法列印", message: "請確認印表機設定後再試一次。（\(error.localizedDescription)）")
            }
        }
    }
}

// MARK: - NSTextViewDelegate

extension EditorController: NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        syncTypingAttributes()
    }

    func textDidChange(_ notification: Notification) {
        flushRestyle()
        if !(storage.length == 0 || storage.string.hasSuffix("\n")) { trailingSemantic = nil }
        invalidateGroup(around: textView.selectedRange().location)
        scheduleOutlineRefresh()
        textView.updateStyleTag(animated: false)
        textView.repositionStyleTagSoon()
        textView.refreshPlaceholder()
    }

    /// 點連結是為了編輯它；按住 Command 點才會打開。
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if NSEvent.modifierFlags.contains(.command), let url = link as? URL {
            NSWorkspace.shared.open(url)
        } else {
            textView.setSelectedRange(NSRange(location: charIndex + 1, length: 0))
            editLink()
        }
        return true
    }
}

// MARK: - NSTextStorageDelegate

extension EditorController: @preconcurrency NSTextStorageDelegate {
    func textStorage(
        _ textStorage: NSTextStorage, willProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange, changeInLength delta: Int
    ) {
        // 不能在這裡直接套樣式：樣式會牽動前後段落，TextKit 會把「這次修改的範圍」跟著擴大，
        // 並把游標移到那個範圍的結尾，結果在文件中間每打一個字游標就跳到下一段。
        // 先記下範圍，等這次修改完成、游標就定位之後再套。
        guard !isRestyling else { return }
        pendingRestyle = pendingRestyle.map { NSUnionRange($0, editedRange) } ?? editedRange
    }

    func textStorage(
        _ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange, changeInLength delta: Int
    ) {
        scheduleSnapshot()
        // 大多數修改會在 `textDidChange` 就套好樣式；這是給不經過文字檢視的修改用的保險。
        DispatchQueue.main.async { [weak self] in self?.flushRestyle() }
    }

    /// 套用先前記下的樣式更新，並把游標放回原位。
    func flushRestyle() {
        guard let range = pendingRestyle, !isRestyling else { return }
        pendingRestyle = nil
        isRestyling = true
        defer { isRestyling = false }
        let selection = textView.selectedRanges
        storage.beginEditing()
        Styling.restyle(storage, in: NSIntersectionRange(range, NSRange(location: 0, length: storage.length)))
        storage.endEditing()
        if textView.selectedRanges != selection { textView.selectedRanges = selection }
    }
}

// MARK: - NSTextLayoutManagerDelegate

extension EditorController: @preconcurrency NSTextLayoutManagerDelegate {
    func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: any NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        let fragment = MeadLayoutFragment(textElement: textElement, range: textElement.elementRange)
        guard let paragraph = textElement as? NSTextParagraph else { return fragment }
        let content = paragraph.attributedString
        let attributes = content.length > 0 ? content.attributes(at: 0, effectiveRange: nil) : textView.typingAttributes
        let style = BlockStyle(rawValue: attributes[.meadBlock] as? String ?? "") ?? .body
        let indent = attributes[.meadIndent] as? Int ?? 0
        let offset = characterOffset(of: location)
        fragment.markerFont = Theme.font(for: .body, bold: false, italic: false, inlineCode: false)

        switch style {
        case .bullet:
            fragment.decoration = .marker(["•", "◦", "▪"][indent % 3])
        case .todo:
            fragment.decoration = .checkbox(attributes[.meadCheck] as? Bool ?? false)
        case .numbered:
            fragment.decoration = .marker("\(ordinal(ofItemAt: offset, indent: indent)).")
            fragment.markerFont = .monospacedDigitSystemFont(ofSize: Theme.fontSize(for: .body), weight: .regular)
        case .quote:
            fragment.decoration = .quote
        case .code:
            let group = attributes[.meadCodeGroup] as? Int
            fragment.decoration = .code(
                isFirst: !codeGroup(group, continuesAt: offset - 1),
                isLast: !codeGroup(group, continuesAt: offset + content.length)
            )
        default:
            break
        }

        // 這一段是文件最後一段且以換行結尾：結尾空行的記號由這個片段代畫。
        if content.string.hasSuffix("\n"), offset + content.length == storage.length {
            let trailing = semanticAttributes(forCaretAt: storage.length)
            let trailingIndent = trailing[.meadIndent] as? Int ?? 0
            fragment.trailingMarkerFont = fragment.markerFont
            switch BlockStyle(rawValue: trailing[.meadBlock] as? String ?? "") ?? .body {
            case .bullet:
                fragment.trailingDecoration = .marker(["•", "◦", "▪"][trailingIndent % 3])
            case .todo:
                fragment.trailingDecoration = .checkbox(false)
            case .numbered:
                fragment.trailingDecoration = .marker("\(ordinal(ofItemAt: storage.length, indent: trailingIndent)).")
                fragment.trailingMarkerFont = .monospacedDigitSystemFont(ofSize: Theme.fontSize(for: .body), weight: .regular)
            default:
                break
            }
        }
        return fragment
    }

    private func ordinal(ofItemAt offset: Int, indent: Int) -> Int {
        var count = 1
        var location = min(offset, storage.length)
        while location > 0 {
            let previous = paragraphRange(at: location - 1)
            let style = storage.blockStyle(at: previous.location)
            guard style.isList else { break }
            let level = storage.indentLevel(at: previous.location)
            if level < indent { break }
            if level == indent {
                guard style == .numbered else { break }
                count += 1
            }
            location = previous.location
        }
        return count
    }

    private func codeGroup(_ group: Int?, continuesAt location: Int) -> Bool {
        guard location >= 0, location < storage.length, storage.blockStyle(at: location) == .code else { return false }
        return storage.attribute(.meadCodeGroup, at: location, effectiveRange: nil) as? Int == group
    }
}


/// 原始格式編輯區的變動通知。
private final class SourceTextDelegate: NSObject, NSTextViewDelegate {
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func textDidChange(_ notification: Notification) {
        onChange()
    }
}
