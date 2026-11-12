import AppKit

extension NSPasteboard.PasteboardType {
    /// App 內部複製貼上用：保留樣式、表格與流程圖。
    static let meadMarkdown = NSPasteboard.PasteboardType("com.okmaster.OKMMead.markdown")
}

/// 置中紙張上的文字檢視。負責擺放紙張與邊界樣式標籤，以及把按鍵轉成文書處理器的行為。
final class MeadTextView: NSTextView {
    weak var editor: EditorController?

    private let styleTag = MarginStyleTag()
    private let pageView = NSView()
    private let placeholder = NSTextField(labelWithString: "")
    private var lastLaidOutWidth: CGFloat = 0
    private var isPositioningStyleTag = false
    /// 紙張上下各留一段畫布底色。
    private static let canvasVerticalMargin: CGFloat = 20

    static func makeScrollable() -> (scrollView: NSScrollView, textView: MeadTextView) {
        let textView = MeadTextView(usingTextLayoutManager: true)
        textView.configure()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        // 畫布底色由視窗底層的毛玻璃提供，這裡保持透明才透得出來。
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        return (scrollView, textView)
    }

    private func configure() {
        isRichText = true
        allowsUndo = true
        importsGraphics = false
        usesFontPanel = false
        usesRuler = false
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        drawsBackground = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        minSize = .zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = true
        textContainer?.lineFragmentPadding = 0
        insertionPointColor = OKMPalette.primary
        selectedTextAttributes = [.backgroundColor: Theme.selection]
        linkTextAttributes = [
            .foregroundColor: OKMPalette.accent,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: OKMPalette.accent.withAlphaComponent(0.45),
            .cursor: NSCursor.pointingHand,
        ]
        setAccessibilityLabel("文件內容")

        pageView.wantsLayer = true
        pageView.layer?.cornerRadius = Theme.pageCornerRadius
        pageView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        pageView.layer?.shadowRadius = 7
        // 放在最底層：TextKit 2 把文字、選取範圍與游標畫在各自的子檢視裡，都會疊在紙張上面。
        addSubview(pageView, positioned: .below, relativeTo: nil)
        applyPageColors()

        placeholder.textColor = OKMPalette.textMuted
        placeholder.isHidden = true
        placeholder.setAccessibilityElement(false)
        addSubview(placeholder)

        styleTag.target = self
        styleTag.action = #selector(showStyleMenu(_:))
        styleTag.isHidden = true
        addSubview(styleTag)
    }

    // MARK: 紙張

    private var pageRect: NSRect {
        let width = min(Theme.pageWidth, bounds.width - Theme.canvasMargin * 2)
        return NSRect(
            x: floor((bounds.width - width) / 2), y: Self.canvasVerticalMargin,
            width: width, height: bounds.height - Self.canvasVerticalMargin * 2
        )
    }

    /// 視窗變窄時紙張跟著縮，內距也等比例縮小，文字欄不會被擠到看不見。
    private var pagePadding: CGFloat {
        let scale = min(1, pageRect.width / Theme.pageWidth)
        return max(36, Theme.pageHorizontalPadding * scale)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutPage()
        guard abs(newSize.width - lastLaidOutWidth) > 0.5 else { return }
        lastLaidOutWidth = newSize.width
        textContainerInset = NSSize(
            width: pageRect.minX + pagePadding,
            height: Self.canvasVerticalMargin + Theme.pageTopPadding
        )
        layoutPage()
        refreshPlaceholder()
        updateStyleTag(animated: false)
    }

    /// 紙張和佔位文字都是獨立的子檢視，這個檢視本身不覆寫 `draw`。
    /// 紙張和整份文件一樣高；若在 `draw` 裡畫它，每捲動一格都要重繪新露出的區域，還要算陰影，會掉格。
    /// 改成只有底色與陰影路徑的圖層後，由圖形處理器直接合成，捲動時不需要任何重繪。
    private func layoutPage() {
        let page = pageRect
        guard pageView.frame != page else { return }
        pageView.frame = page
        pageView.layer?.shadowPath = CGPath(
            roundedRect: CGRect(origin: .zero, size: page.size),
            cornerWidth: Theme.pageCornerRadius, cornerHeight: Theme.pageCornerRadius, transform: nil
        )
    }

    private func applyPageColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            guard let layer = pageView.layer else { return }
            layer.backgroundColor = Theme.page.cgColor
            layer.shadowColor = OKMPalette.navy950.cgColor
            layer.shadowOpacity = effectiveAppearance.isDark ? 0.5 : 0.10
        }
    }

    /// 空白文件的提示文字，位置與字級對齊實際輸入的第一行。
    func refreshPlaceholder() {
        let isEmpty = (textStorage?.length ?? 0) == 0
        placeholder.isHidden = !isEmpty
        guard isEmpty else { return }
        let style = editor?.currentStyle ?? .title
        let font = Theme.font(for: style, bold: false, italic: false, inlineCode: false)
        placeholder.stringValue = style == .title ? "文件標題" : "開始輸入…"
        placeholder.font = font
        placeholder.sizeToFit()
        // 行高倍數讓第一行的字比行框頂端低一些。
        let lineHeight = font.ascender - font.descender + font.leading
        let extra = lineHeight * (style.isHeading ? 0.2 : 0.45)
        placeholder.setFrameOrigin(NSPoint(x: textContainerOrigin.x, y: textContainerOrigin.y + extra))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPageColors()
    }

    // MARK: 邊界樣式標籤

    /// 把標籤移到游標所在段落的第一行旁邊。
    func updateStyleTag(animated: Bool) {
        guard let editor, window?.firstResponder === self, !editor.selectionIsAttachment,
              let baseline = firstLineBaseline(ofParagraphAt: selectedRange().location) else {
            styleTag.isHidden = true
            return
        }
        styleTag.title = editor.currentStyle.displayName
        styleTag.sizeToFit()
        let origin = NSPoint(
            x: textContainerOrigin.x - styleTag.frame.width - 14,
            // 對齊第一行字身的中心（基線往上半個大寫高度），而不是含行距的行框中心。
            y: baseline - Theme.font(for: editor.currentStyle, bold: false, italic: false, inlineCode: false).capHeight / 2
                - styleTag.frame.height / 2
        )
        let wasHidden = styleTag.isHidden
        styleTag.isHidden = false
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if animated, !wasHidden, !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
                styleTag.animator().setFrameOrigin(origin)
            }
        } else {
            styleTag.setFrameOrigin(origin)
        }
    }

    private func firstLineBaseline(ofParagraphAt characterIndex: Int) -> CGFloat? {
        guard let layoutManager = textLayoutManager, let contentManager = layoutManager.textContentManager else { return nil }
        // 直接讀文字儲存區；`string` 每次都會複製整份文字，而這裡每次排版都會被呼叫。
        guard let text = textStorage?.mutableString else { return nil }
        // 文件結尾的空行沒有自己的排版片段，它是上一段片段裡的最後一行。
        let isTrailingEmptyLine = characterIndex >= text.length && text.length > 0 && text.character(at: text.length - 1) == 0x0A
        let probe = isTrailingEmptyLine ? text.length - 1 : min(characterIndex, text.length)
        let paragraphStart = text.paragraphRange(for: NSRange(location: probe, length: 0)).location
        guard let location = contentManager.location(contentManager.documentRange.location, offsetBy: paragraphStart) else { return nil }
        // 只讀已經排好的結果，不在這裡強迫排版：視窗還沒定好寬度時強迫排版，
        // 表格與流程圖會以錯誤的寬度量尺寸。排版完成後 `layout()` 會再呼叫一次來對位。
        guard let fragment = layoutManager.textLayoutFragment(for: location) else { return nil }
        let frame = fragment.layoutFragmentFrame
        let lines = fragment.textLineFragments
        guard let line = isTrailingEmptyLine ? lines.last : lines.first else { return textContainerOrigin.y + frame.midY }
        return textContainerOrigin.y + frame.minY + line.typographicBounds.minY + line.glyphOrigin.y
    }

    /// 排版在文字變動後才陸續完成（例如上面的表格或流程圖量好高度），標籤要跟著重新對位。
    override func layout() {
        super.layout()
        guard !isPositioningStyleTag, bounds.width > 200 else { return }
        isPositioningStyleTag = true
        updateStyleTag(animated: false)
        isPositioningStyleTag = false
    }

    /// 文字變動後，表格或流程圖可能稍後才量好高度；等這一輪排版結束再對位一次。
    func repositionStyleTagSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.needsLayout = true
        }
    }

    @objc private func showStyleMenu(_ sender: NSButton) {
        guard let editor else { return }
        let menu = NSMenu()
        for style in BlockStyle.pickable {
            let item = NSMenuItem(title: style.displayName, action: #selector(pickStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.state = style == editor.currentStyle ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: menu.items.first { $0.state == .on }, at: NSPoint(x: 0, y: 0), in: sender)
    }

    @objc private func pickStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let style = BlockStyle(rawValue: raw) else { return }
        editor?.setBlockStyle(style)
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { DispatchQueue.main.async { [weak self] in self?.updateStyleTag(animated: false) } }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { styleTag.isHidden = true }
        return resigned
    }

    // MARK: 按鍵

    override func insertNewline(_ sender: Any?) {
        if editor?.handleReturn() == true { return }
        super.insertNewline(sender)
        editor?.didInsertNewline()
    }

    override func deleteBackward(_ sender: Any?) {
        if editor?.handleDeleteAtParagraphStart() == true { return }
        super.deleteBackward(sender)
    }

    override func insertTab(_ sender: Any?) {
        // Markdown 存不住內文的縮排；Tab 只在清單裡有作用。
        editor?.changeListIndent(by: 1)
    }

    override func insertBacktab(_ sender: Any?) {
        editor?.changeListIndent(by: -1)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        editor?.moveCaretOffAttachmentParagraph()
        super.insertText(string, replacementRange: replacementRange)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if editor?.toggleCheckbox(at: point) == true { return }
        super.mouseDown(with: event)
    }

    /// 文字檢視座標 → 該點所在的排版片段，以及片段座標系中的位置。
    func layoutFragment(at point: NSPoint) -> (fragment: NSTextLayoutFragment, local: CGPoint)? {
        guard let layoutManager = textLayoutManager else { return nil }
        let origin = textContainerOrigin
        let containerPoint = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        guard let fragment = layoutManager.textLayoutFragment(for: containerPoint) else { return nil }
        let frame = fragment.layoutFragmentFrame
        return (fragment, CGPoint(x: containerPoint.x - frame.minX, y: containerPoint.y - frame.minY))
    }

    // MARK: 剪貼簿

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [.meadMarkdown, .string]
    }

    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard let storage = textStorage, type == .meadMarkdown || type == .string else { return false }
        let selection = storage.attributedSubstring(from: selectedRange())
        let markdown = MarkdownExporter.markdown(from: selection).trimmingCharacters(in: .newlines)
        return pboard.setString(markdown, forType: type)
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [.meadMarkdown, .string]
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard let text = pboard.string(forType: type) else { return false }
        editor?.paste(text, isMarkdown: type == .meadMarkdown)
        return true
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

/// 段落旁的樣式名稱。平常是低調的說明文字，滑鼠移上去才顯示成可按的樣子。
private final class MarginStyleTag: NSButton {
    private var isHovered = false { didSet { needsDisplay = true } }
    /// 文字右邊的小箭頭，提示這個標籤可以點開。
    private static let chevronWidth: CGFloat = 10

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        font = .systemFont(ofSize: 11, weight: .medium)
        setButtonType(.momentaryChange)
        toolTip = "更改這一段的樣式"
        setAccessibilityLabel("段落樣式")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MarginStyleTag 不支援封存")
    }

    override var intrinsicContentSize: NSSize {
        let size = (title as NSString).size(withAttributes: [.font: font ?? .systemFont(ofSize: 11)])
        return NSSize(width: ceil(size.width) + 12 + Self.chevronWidth, height: 18)
    }

    override func sizeToFit() {
        setFrameSize(intrinsicContentSize)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            Theme.tint.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: 11),
            .foregroundColor: isHovered ? OKMPalette.primary : OKMPalette.textMuted,
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        let color = isHovered ? OKMPalette.primary : OKMPalette.textMuted
        (title as NSString).draw(
            at: NSPoint(x: bounds.maxX - size.width - 6 - Self.chevronWidth, y: (bounds.height - size.height) / 2),
            withAttributes: attributes
        )
        let configuration = NSImage.SymbolConfiguration(pointSize: 6.5, weight: .bold)
            .applying(.init(paletteColors: [color.withAlphaComponent(isHovered ? 1 : 0.7)]))
        if let chevron = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) {
            let origin = NSPoint(x: bounds.maxX - 5 - chevron.size.width, y: (bounds.height - chevron.size.height) / 2)
            chevron.draw(in: NSRect(origin: origin, size: chevron.size))
        }
    }
}
