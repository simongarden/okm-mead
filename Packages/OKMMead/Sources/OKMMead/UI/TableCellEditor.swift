// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit
import SwiftUI

/// 表格儲存格的輸入欄位。內容以行內 Markdown 存在資料模型裡，畫面上顯示成排版好的文字
/// （粗體、斜體、刪除線、行內程式碼、連結），不露出語法記號。
struct TableCellEditor: NSViewRepresentable {
    let markdown: String
    let isHeader: Bool
    let placeholder: String?
    let accessibilityLabel: String
    /// 要求把輸入焦點移到這一格（例如在上一格按 Return）。
    let wantsFocus: Bool
    weak var editor: EditorController?
    let onChange: (String) -> Void
    let onFocusChange: (Bool) -> Void
    let onSubmit: () -> Void
    let menuItems: () -> [TableCellMenuItem]

    func makeNSView(context: Context) -> TableCellTextView {
        let view = TableCellTextView(isHeader: isHeader)
        view.load(markdown)
        return view
    }

    func updateNSView(_ view: TableCellTextView, context: Context) {
        view.editor = editor
        view.placeholder = placeholder
        view.onChange = onChange
        view.onFocusChange = onFocusChange
        view.onSubmit = onSubmit
        view.menuItems = menuItems
        view.setAccessibilityLabel(accessibilityLabel)
        // 只有外來的變動（復原、增減列）才重新載入；自己剛送出去的內容不必再讀回來，游標才不會跳。
        if markdown != view.syncedMarkdown { view.load(markdown) }
        if wantsFocus, view.window?.firstResponder !== view {
            DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: TableCellTextView, context: Context) -> CGSize? {
        // 沒有指定寬度時回報很小的理想寬度，各欄才會平均分配。
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return CGSize(width: 40, height: nsView.height(forWidth: 400))
        }
        return CGSize(width: width, height: nsView.height(forWidth: width))
    }
}

struct TableCellMenuItem {
    var title: String
    var isEnabled = true
    var isSeparator = false
    var action: () -> Void = {}

    static var separator: TableCellMenuItem { TableCellMenuItem(title: "", isSeparator: true) }
}

final class TableCellTextView: NSTextView {
    weak var editor: EditorController?
    var placeholder: String? { didSet { if placeholder != oldValue { needsDisplay = true } } }
    var onChange: ((String) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var onSubmit: (() -> Void)?
    var menuItems: (() -> [TableCellMenuItem])?
    /// 上一次和資料模型同步時的 Markdown。
    private(set) var syncedMarkdown = ""

    private let isHeader: Bool
    private var linkPopover: NSPopover?

    private static let fontSize: CGFloat = 14
    private static let semanticKeys: [NSAttributedString.Key] = [.meadBold, .meadItalic, .meadStrike, .meadInlineCode, .meadRawInline, .link]
    private static let derivedKeys: [NSAttributedString.Key] = [.font, .foregroundColor, .strikethroughStyle, .backgroundColor, .paragraphStyle]

    init(isHeader: Bool) {
        self.isHeader = isHeader
        // 明確使用 TextKit 1：儲存格很小，量高度用 layoutManager 最直接。
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        super.init(frame: .zero, textContainer: container)

        delegate = self
        drawsBackground = false
        isRichText = true
        importsGraphics = false
        // 復原交給文件：每次變動都會登記在文件的復原堆疊裡。
        allowsUndo = false
        textContainerInset = .zero
        isVerticallyResizable = false
        isHorizontallyResizable = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        insertionPointColor = Palette.primary
        if let selection = MeadConfiguration.appearance.selection { selectedTextAttributes = [.backgroundColor: selection] }
        linkTextAttributes = [
            .foregroundColor: Palette.accent,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: Palette.accent.withAlphaComponent(0.45),
            .cursor: NSCursor.pointingHand,
        ]
        typingAttributes = display(for: [:])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("不支援從 nib 建立") }

    // MARK: 內容

    func load(_ markdown: String) {
        syncedMarkdown = markdown
        let content = InlineMarkdown.attributedString(from: markdown)
        textStorage?.setAttributedString(content)
        restyle()
        needsDisplay = true
    }

    /// 由語意屬性重新推導字型與顏色。儲存格很短，每次整格重算。
    private func restyle() {
        guard let storage = textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        var runs: [(NSRange, [NSAttributedString.Key: Any])] = []
        storage.enumerateAttributes(in: full) { attributes, range, _ in runs.append((range, attributes)) }
        storage.beginEditing()
        for (range, attributes) in runs {
            let derived = display(for: attributes)
            for key in Self.derivedKeys {
                if let value = derived[key] {
                    storage.addAttribute(key, value: value, range: range)
                } else {
                    storage.removeAttribute(key, range: range)
                }
            }
        }
        storage.endEditing()
    }

    /// 語意屬性加上由它推導出來的顯示屬性。
    private func display(for semantic: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var attributes = semantic.filter { Self.semanticKeys.contains($0.key) }
        let bold = semantic[.meadBold] as? Bool == true
        let raw = semantic[.meadRawInline] != nil
        var font: NSFont
        if semantic[.meadInlineCode] as? Bool == true {
            font = .monospacedSystemFont(ofSize: Self.fontSize - 1, weight: bold || isHeader ? .semibold : .regular)
            attributes[.backgroundColor] = Theme.pageSunken
        } else {
            font = .systemFont(ofSize: Self.fontSize, weight: bold ? .bold : isHeader ? .semibold : .regular)
        }
        if semantic[.meadItalic] as? Bool == true {
            let slant = AffineTransform(m11: 1, m12: 0, m21: Theme.italicSlant, m22: 1, tX: 0, tY: 0)
            font = NSFont(descriptor: font.fontDescriptor, textTransform: slant) ?? font
        }
        if raw { attributes[.backgroundColor] = Theme.pageSunken }
        if semantic[.meadStrike] as? Bool == true {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        attributes[.font] = font
        attributes[.foregroundColor] = raw ? Palette.textMuted : Palette.text
        attributes[.paragraphStyle] = paragraph
        return attributes
    }

    private func commit() {
        guard let storage = textStorage, !hasMarkedText() else { return }
        let markdown = InlineMarkdown.markdown(from: storage)
        guard markdown != syncedMarkdown else { return }
        syncedMarkdown = markdown
        onChange?(markdown)
    }

    func height(forWidth width: CGFloat) -> CGFloat {
        guard let container = textContainer, let layoutManager else { return 20 }
        container.size = NSSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let line = layoutManager.defaultLineHeight(for: .systemFont(ofSize: Self.fontSize)) + 3
        return ceil(max(layoutManager.usedRect(for: container).height, line))
    }

    // MARK: 格式指令

    private func semantic(at location: Int) -> [NSAttributedString.Key: Any] {
        guard let storage = textStorage, storage.length > 0 else { return typingAttributes }
        let probe = selectedRange().length > 0 ? location : location - 1
        guard probe >= 0, probe < storage.length else { return typingAttributes }
        return storage.attributes(at: probe, effectiveRange: nil)
    }

    private func reportSelection() {
        let selection = selectedRange()
        let attributes = selection.length == 0 ? typingAttributes : semantic(at: selection.location)
        editor?.cellSelectionDidChange(
            bold: attributes[.meadBold] as? Bool == true,
            italic: attributes[.meadItalic] as? Bool == true,
            strikethrough: attributes[.meadStrike] as? Bool == true
        )
    }

    /// 切換粗體、斜體或刪除線。沒有選取文字時改的是接下來要輸入的字。
    func toggle(_ key: NSAttributedString.Key) {
        guard let storage = textStorage else { return }
        let selection = selectedRange()
        if selection.length == 0 {
            var semantic = typingAttributes
            semantic[key] = semantic[key] as? Bool == true ? nil : true
            typingAttributes = display(for: semantic)
            reportSelection()
            return
        }
        var allOn = true
        storage.enumerateAttribute(key, in: selection) { value, _, stop in
            if value as? Bool != true { allOn = false; stop.pointee = true }
        }
        if allOn {
            storage.removeAttribute(key, range: selection)
        } else {
            storage.addAttribute(key, value: true, range: selection)
        }
        restyle()
        commit()
        reportSelection()
    }

    func editLink() {
        guard let storage = textStorage else { return }
        var range = selectedRange()
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
        let text = (storage.string as NSString).substring(with: range)
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
                self?.textStorage?.removeAttribute(.link, range: range)
                self?.finishLinkEdit(caret: NSMaxRange(range))
            },
            onOpen: { url in NSWorkspace.shared.open(url) }
        ))
        linkPopover = popover
        var anchor = bounds
        if let layoutManager, let container = textContainer, range.length > 0 {
            let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            anchor = layoutManager.boundingRect(forGlyphRange: glyphs, in: container)
        }
        popover.show(relativeTo: anchor, of: self, preferredEdge: .maxY)
    }

    private func applyLink(_ url: URL, text: String, to range: NSRange) {
        guard let storage = textStorage, NSMaxRange(range) <= storage.length else { return }
        let label = text.isEmpty ? url.absoluteString : text
        var attributes = range.length > 0 ? storage.attributes(at: range.location, effectiveRange: nil) : typingAttributes
        attributes[.link] = url
        storage.replaceCharacters(in: range, with: NSAttributedString(string: label, attributes: attributes))
        finishLinkEdit(caret: range.location + (label as NSString).length)
    }

    private func finishLinkEdit(caret: Int) {
        restyle()
        commit()
        window?.makeFirstResponder(self)
        setSelectedRange(NSRange(location: min(caret, textStorage?.length ?? 0), length: 0))
    }

    // MARK: 焦點、按鍵與選單

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            editor?.cellDidBecomeActive(self)
            onFocusChange?(true)
            reportSelection()
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted {
            commit()
            editor?.cellDidResignActive(self)
            onFocusChange?(false)
        }
        return accepted
    }

    /// 從別處貼上的文字只取內容，不帶入外來的字型與顏色。
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let items = menuItems?(), !items.isEmpty else { return nil }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for item in items {
            if item.isSeparator {
                menu.addItem(.separator())
            } else {
                let entry = ClosureMenuItem(title: item.title, handler: item.action)
                entry.isEnabled = item.isEnabled
                menu.addItem(entry)
            }
        }
        return menu
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let placeholder, string.isEmpty, !hasMarkedText() else { return }
        var attributes = display(for: [:])
        attributes[.foregroundColor] = Palette.textMuted.withAlphaComponent(0.7)
        NSAttributedString(string: placeholder, attributes: attributes).draw(at: .zero)
    }
}

extension TableCellTextView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        // 注音等輸入法還在組字時不重排樣式，否則組字中的文字會被打斷。
        guard !hasMarkedText() else { return }
        let selection = selectedRanges
        restyle()
        selectedRanges = selection
        commit()
        needsDisplay = true
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard window?.firstResponder === self else { return }
        // 游標移到別處後，接下來輸入的字沿用游標前一個字的格式。
        if selectedRange().length == 0, let storage = textStorage {
            let location = selectedRange().location
            typingAttributes = location > 0 && location <= storage.length
                ? display(for: storage.attributes(at: location - 1, effectiveRange: nil))
                : display(for: [:])
        }
        reportSelection()
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(insertNewline(_:)):
            commit()
            onSubmit?()
            return true
        case #selector(insertTab(_:)):
            window?.selectNextKeyView(self)
            return true
        case #selector(insertBacktab(_:)):
            window?.selectPreviousKeyView(self)
            return true
        default:
            return false
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if NSEvent.modifierFlags.contains(.command) {
            if let url = link as? URL, ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
        } else {
            window?.makeFirstResponder(self)
            setSelectedRange(NSRange(location: charIndex + 1, length: 0))
            editLink()
        }
        return true
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("不支援封存") }

    @objc private func run() { handler() }
}
