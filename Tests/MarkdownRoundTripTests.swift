import XCTest
@testable import OKMMead
@testable import OKMMeadApp

@MainActor
final class MarkdownRoundTripTests: XCTestCase {
    private func roundTrip(_ markdown: String) -> String {
        MarkdownExporter.markdown(from: MarkdownImporter.attributedString(from: markdown))
    }

    func testCanonicalDocumentSurvivesUnchanged() {
        let source = """
        # 專案說明

        這份文件說明**新版請款流程**，詳情見[內部網站](https://example.com/flow)。

        ## 步驟

        - 填寫申請單
            - 附上發票
        - 主管簽核

        1. 第一項
        2. 第二項

        待辦事項：

        - [ ] 待辦
        - [x] 完成

        > 引言第一段
        >
        > 引言第二段

        | 項目 | 金額 |
        | --- | --- |
        | 交通 | 1,200 |

        ```mermaid
        flowchart TD
            n1(["開始"])
            n2["審核"]
            n1 --> n2
        ```

        ---

        ```swift
        let x = 1
        ```

        """
        XCTAssertEqual(roundTrip(source), source)
    }

    func testEmphasisNextToFullWidthPunctuationStaysValid() {
        // 「**注意：**請」在 CommonMark 不算粗體；標點要移到記號外面。
        let text = NSMutableAttributedString(string: "注意：請先存檔", attributes: [.meadBlock: BlockStyle.body.rawValue])
        text.addAttribute(.meadBold, value: true, range: NSRange(location: 0, length: 3))
        let output = MarkdownExporter.markdown(from: text)
        XCTAssertEqual(output, "**注意**：請先存檔\n")
        let reparsed = MarkdownImporter.attributedString(from: output)
        XCTAssertEqual(reparsed.string, "注意：請先存檔")
        XCTAssertTrue(reparsed.flag(.meadBold, at: 0))
        XCTAssertFalse(reparsed.flag(.meadBold, at: 2))
    }

    func testLiteralMarkersAreEscaped() {
        let text = NSMutableAttributedString(string: "# 不是標題\n1. 不是清單\n價格 *未稅*", attributes: [.meadBlock: BlockStyle.body.rawValue])
        let output = MarkdownExporter.markdown(from: text)
        XCTAssertEqual(output, "\\# 不是標題\n\n1\\. 不是清單\n\n價格 \\*未稅\\*\n")
        let reparsed = MarkdownImporter.attributedString(from: output)
        XCTAssertEqual(reparsed.string, text.string)
        XCTAssertEqual(reparsed.blockStyle(at: 0), .body)
    }

    func testSoftBreaksBetweenChineseCharactersDoNotAddSpaces() {
        XCTAssertEqual(MarkdownImporter.attributedString(from: "第一行\n第二行").string, "第一行第二行")
        XCTAssertEqual(MarkdownImporter.attributedString(from: "hello\nworld").string, "hello world")
    }

    func testDeepHeadingsKeepTheirLevel() {
        let source = "# 一\n\n### 三\n\n#### 四\n\n##### 五\n\n###### 六\n\n內文\n"
        XCTAssertEqual(roundTrip(source), source)
    }

    func testFrontMatterIsKeptVerbatim() {
        let source = "---\ntitle: 請款流程\ntags: [財務, 流程]\n---\n\n# 標題\n\n內文\n"
        XCTAssertEqual(roundTrip(source), source)
        XCTAssertEqual(roundTrip("內文\n\n---\n\n結尾\n"), "內文\n\n---\n\n結尾\n")
    }

    func testTableCellsKeepInlineFormatting() {
        let source = "| 項目 | 說明 |\n| --- | --- |\n| **重點** | 見 `README.md` 與[網站](https://example.com) |\n"
        XCTAssertEqual(roundTrip(source), source)
    }

    func testReadOnlyPreviewKeepsContent() {
        let preview = MeadPreviewView(markdown: "# 一\n\n## 二\n\n**粗體**文字\n", fileURL: nil)
        XCTAssertEqual(preview.headingCount, 2)
        XCTAssertTrue(preview.plainText.contains("粗體文字"))
    }

    func testPastedMarkdownIsRecognized() {
        XCTAssertTrue(EditorController.looksLikeMarkdown("## 標題\n內容"))
        XCTAssertTrue(EditorController.looksLikeMarkdown("這是**重點**"))
        XCTAssertFalse(EditorController.looksLikeMarkdown("台北市信義區\n市府路 1 號"))
    }
}

@MainActor
final class FlowchartTests: XCTestCase {
    func testGeneratedMermaidParsesBack() throws {
        var chart = Flowchart.starter
        chart.nodes[1].shape = .decision
        chart.edges[1].label = "是"
        let parsed = try XCTUnwrap(Flowchart(mermaid: chart.mermaid))
        XCTAssertEqual(parsed, chart)
    }

    func testHandWrittenFlowchartIsUnderstood() throws {
        let parsed = try XCTUnwrap(Flowchart(mermaid: "graph LR\n  A[申請] --> B{金額大於一萬?}\n  B -- 是 --> C(主管簽核)\n  B -->|否| D[直接核准]"))
        XCTAssertEqual(parsed.direction, .right)
        XCTAssertEqual(parsed.nodes.map(\.text), ["申請", "金額大於一萬?", "主管簽核", "直接核准"])
        XCTAssertEqual(parsed.nodes[1].shape, .decision)
        XCTAssertEqual(parsed.edges.map(\.label), ["", "是", "否"])
    }

    func testUnsupportedDiagramsFallBackToText() {
        XCTAssertNil(Flowchart(mermaid: "sequenceDiagram\n  A->>B: hi"))
        XCTAssertNil(Flowchart(mermaid: "flowchart TD\n  subgraph one\n  A --> B\n  end"))
        XCTAssertNil(Flowchart(mermaid: "flowchart TD\n  A -.-> B"))
    }
}

@MainActor
final class PDFExportTests: XCTestCase {
    override func setUp() async throws {
        // Mermaid 由 App 提供給編輯核心。
        EditorSetup.configure()
    }

    func testExportWritesPaginatedPDFWithDiagram() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("okm-mead-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        let filler = (1...80).map { "第 \($0) 段：這是用來測試分頁的內文。" }.joined(separator: "\n\n")
        let markdown = "# 測試文件\n\n| 甲 | 乙 |\n| --- | --- |\n| 1 | 2 |\n\n```mermaid\n\(Flowchart.starter.mermaid)\n```\n\n\(filler)\n"
        try await PDFExporter.export(markdown: markdown, to: url, window: window)

        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))
        XCTAssertGreaterThan(document.numberOfPages, 1)
        if let output = ProcessInfo.processInfo.environment["OKMMEAD_TEST_PDF_COPY"] {
            try? FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: output))
        }
    }
}

/// 模擬使用者打字與按工具列，確認存出來的 Markdown。
@MainActor
final class EditingBehaviorTests: XCTestCase {
    private func type(_ text: String, into editor: EditorController) {
        editor.textView.insertText(text, replacementRange: editor.textView.selectedRange())
    }

    func testNewDocumentStartsWithTitleThenBody() {
        let editor = EditorController(markdown: "")
        XCTAssertEqual(editor.currentStyle, .title)
        type("會議記錄", into: editor)
        editor.textView.insertNewline(nil)
        XCTAssertEqual(editor.currentStyle, .body)
        type("今天討論三件事。", into: editor)
        XCTAssertEqual(editor.markdown, "# 會議記錄\n\n今天討論三件事。\n")
    }

    func testListContinuesAndEmptyItemLeavesList() {
        let editor = EditorController(markdown: "")
        editor.setBlockStyle(.numbered)
        type("第一", into: editor)
        editor.textView.insertNewline(nil)
        type("第二", into: editor)
        editor.textView.insertNewline(nil)
        editor.textView.insertNewline(nil)
        XCTAssertEqual(editor.currentStyle, .body)
        type("結論", into: editor)
        XCTAssertEqual(editor.markdown, "1. 第一\n2. 第二\n\n結論\n")
    }

    func testBoldSelectionAndStyleChangeInMiddleOfDocument() {
        let editor = EditorController(markdown: "第一段\n\n第二段\n")
        editor.textView.setSelectedRange(NSRange(location: 0, length: 2))
        editor.toggleBold()
        editor.textView.setSelectedRange(NSRange(location: 5, length: 0))
        editor.setBlockStyle(.heading)
        XCTAssertEqual(editor.markdown, "**第一**段\n\n## 第二段\n")
        editor.textView.undoManager?.undo()
        editor.textView.undoManager?.undo()
    }

    func testInsertedTableSitsInItsOwnParagraph() {
        let editor = EditorController(markdown: "前言\n")
        editor.textView.setSelectedRange(NSRange(location: 2, length: 0))
        editor.insertTable()
        type("後記", into: editor)
        let markdown = editor.markdown
        XCTAssertTrue(markdown.hasPrefix("前言\n\n| "), markdown)
        XCTAssertTrue(markdown.hasSuffix(" |\n\n後記\n"), markdown)
        XCTAssertEqual(markdown.components(separatedBy: "\n").filter { $0.hasPrefix("|") }.count, 4)
    }

    func testPastedMarkdownBecomesStyledContent() {
        let editor = EditorController(markdown: "")
        editor.setBlockStyle(.body)
        editor.paste("## 重點\n\n- 甲\n- 乙", isMarkdown: false)
        XCTAssertEqual(editor.markdown, "## 重點\n\n- 甲\n- 乙\n")
        XCTAssertFalse(editor.textView.string.contains("#"))
    }
}

/// 文件結尾的空行沒有自己的段落，容易漏畫清單記號或在打字後位移。
@MainActor
final class TrailingLineTests: XCTestCase {
    private func lastFragment(of editor: EditorController) -> MeadLayoutFragment? {
        let layoutManager = editor.textView.textLayoutManager!
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        var last: NSTextLayoutFragment?
        layoutManager.enumerateTextLayoutFragments(from: layoutManager.documentRange.location, options: [.ensuresLayout]) {
            last = $0
            return true
        }
        return last as? MeadLayoutFragment
    }

    func testTodoStyleCanBeChosenAndRoundTrips() {
        let editor = EditorController(markdown: "買牛奶\n")
        editor.textView.setSelectedRange(NSRange(location: 0, length: 0))
        editor.setBlockStyle(.todo)
        XCTAssertEqual(editor.markdown, "- [ ] 買牛奶\n")
        XCTAssertEqual(MarkdownImporter.attributedString(from: "- [x] 完成\n- 一般項目\n").blockStyle(at: 0), .todo)
        editor.setBlockStyle(.bullet)
        XCTAssertEqual(editor.markdown, "- 買牛奶\n")
    }

    func testNewEmptyListItemShowsItsMarkAndDoesNotMoveWhenTyped() {
        let editor = EditorController(markdown: "- [x] 確認\n- [ ] 送出\n")
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor.scrollView
        let textView = editor.textView
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
        textView.insertNewline(nil)

        guard case .checkbox(false)? = lastFragment(of: editor)?.trailingDecoration else {
            return XCTFail("新的空白待辦項目應該立刻顯示未勾選的方框")
        }
        let before = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil).origin.y
        textView.insertText("字", replacementRange: textView.selectedRange())
        let after = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil).origin.y
        XCTAssertEqual(before, after, accuracy: 0.5, "打第一個字之後，這一行不應該上下移動")
        XCTAssertEqual(editor.markdown, "- [x] 確認\n- [ ] 送出\n- [ ] 字\n")
    }

    func testNewEmptyNumberedItemShowsNextNumber() {
        let editor = EditorController(markdown: "1. 甲\n2. 乙\n")
        let textView = editor.textView
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
        textView.insertNewline(nil)
        guard case .marker("3.")? = lastFragment(of: editor)?.trailingDecoration else {
            return XCTFail("新的空白編號項目應該顯示 3.")
        }
    }
}

@MainActor
final class DocumentSavingTests: XCTestCase {
    /// 重現自動儲存的呼叫方式：主執行緒停著等，背景執行緒來要快照。
    func testSnapshotCanBeTakenFromBackgroundThreadWhileMainThreadWaits() throws {
        let document = MeadDocument()
        let editor = document.editor
        editor.textView.insertText("標題", replacementRange: editor.textView.selectedRange())
        editor.textView.insertNewline(nil)
        editor.insertTable()

        // 編輯後的下一輪事件處理才會更新存檔用的快照。
        let settled = expectation(description: "快照已更新")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2)

        // 用另一條執行緒要快照，主執行緒同步等它，和 AppKit 自動儲存時一樣。
        nonisolated(unsafe) var result: Result<String, Error>?
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            result = Result { try document.snapshot(contentType: .markdownDocument) }
            done.signal()
        }
        thread.start()
        XCTAssertEqual(done.wait(timeout: .now() + 5), .success, "背景執行緒拿不到快照")
        let markdown = try XCTUnwrap(result).get()
        XCTAssertTrue(markdown.hasPrefix("# 標題\n\n| "), markdown)
    }
}

@MainActor
final class SourceModeTests: XCTestCase {
    func testEditingSourceReplacesDocumentAndCanBeToggledBack() {
        let editor = EditorController(markdown: "# 舊標題\n")
        editor.toggleSourceMode()
        XCTAssertTrue(editor.isSourceMode)
        XCTAssertEqual(editor.sourceTextView.string, "# 舊標題\n")

        editor.sourceTextView.string = "## 新標題\n\n- [ ] 待辦\n"
        XCTAssertEqual(editor.markdown, "## 新標題\n\n- [ ] 待辦\n", "原始格式下存檔要存目前打的文字")

        editor.toggleSourceMode()
        XCTAssertFalse(editor.isSourceMode)
        XCTAssertEqual(editor.textView.string, "新標題\n待辦")
        XCTAssertEqual(editor.currentStyle, .heading)
        XCTAssertEqual(editor.markdown, "## 新標題\n\n- [ ] 待辦\n")
    }

    func testFormattingCommandsAreIgnoredInSourceMode() {
        let editor = EditorController(markdown: "內文\n")
        editor.toggleSourceMode()
        editor.setBlockStyle(.title)
        editor.insertTable()
        editor.toggleSourceMode()
        XCTAssertEqual(editor.markdown, "內文\n")
    }
}

/// 在長文件中間打字：游標只能逐字前進，畫面不能自己捲動。
@MainActor
final class MidDocumentTypingTests: XCTestCase {
    func testTypingInTheMiddleKeepsCaretAndScrollPosition() async throws {
        let section = "## 小節\n\n這是一段內文，用來把文件撐長。\n\n- 項目一\n- 項目二\n\n| 甲 | 乙 |\n| --- | --- |\n| 1 | 2 |\n\n"
        let editor = EditorController(markdown: String(repeating: section, count: 30))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor.scrollView
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        let textView = editor.textView
        window.makeFirstResponder(textView)

        let text = textView.string as NSString
        let target = text.range(of: "把文件撐長。", options: [], range: NSRange(location: text.length / 2, length: text.length / 2))
        var caret = NSMaxRange(target)
        textView.setSelectedRange(NSRange(location: caret, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
        try await Task.sleep(for: .milliseconds(400))
        let scrollBefore = editor.scrollView.contentView.bounds.origin.y

        for character in "接著打幾個字" {
            textView.insertText(String(character), replacementRange: textView.selectedRange())
            try await Task.sleep(for: .milliseconds(30))
            caret += 1
            XCTAssertEqual(textView.selectedRange(), NSRange(location: caret, length: 0), "游標應該只前進一個字")
        }
        XCTAssertEqual(editor.scrollView.contentView.bounds.origin.y, scrollBefore, accuracy: 1, "打字時畫面不應該自己捲動")
        XCTAssertTrue(editor.markdown.contains("把文件撐長。接著打幾個字\n"))
    }

    func testMergingParagraphsWithDeleteKeepsCaretAtTheJoin() {
        let editor = EditorController(markdown: "## 標題\n\n內文\n\n結尾\n")
        let textView = editor.textView
        // 游標放在「內文」開頭，按 Delete 併入上一段標題。
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        textView.deleteBackward(nil)
        XCTAssertEqual(textView.string, "標題內文\n結尾")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 0), "游標應該停在兩段接起來的地方")
        XCTAssertEqual(editor.markdown, "## 標題內文\n\n結尾\n")
    }
}

@MainActor
final class TableCellFormattingTests: XCTestCase {
    func testCellMarkdownBecomesFormattedTextWithoutSyntax() {
        let text = InlineMarkdown.attributedString(from: "**粗體** 與 [連結](https://example.com) 和 `程式碼`")
        XCTAssertEqual(text.string, "粗體 與 連結 和 程式碼", "畫面上不該出現星號、方括號或反引號")
        XCTAssertEqual(text.attribute(.meadBold, at: 0, effectiveRange: nil) as? Bool, true)
        XCTAssertNil(text.attribute(.meadBold, at: 3, effectiveRange: nil))
        XCTAssertEqual((text.attribute(.link, at: 5, effectiveRange: nil) as? URL)?.absoluteString, "https://example.com")
        XCTAssertEqual(text.attribute(.meadInlineCode, at: 10, effectiveRange: nil) as? Bool, true)
        XCTAssertEqual(InlineMarkdown.markdown(from: text), "**粗體** 與 [連結](https://example.com) 和 `程式碼`")
    }

    func testCellKeepsLinesAndLeadingMarkers() {
        // 開頭的「1.」在儲存格裡只是文字，不是清單。
        let text = InlineMarkdown.attributedString(from: "1. *第一行*\n第二行 a|b")
        XCTAssertEqual(text.string, "1. 第一行\n第二行 a|b")
        XCTAssertEqual(text.attribute(.meadItalic, at: 3, effectiveRange: nil) as? Bool, true)
        XCTAssertEqual(InlineMarkdown.markdown(from: text), "1. *第一行*\n第二行 a|b")
    }

    func testLiteralSyntaxInCellsStaysLiteral() {
        let source = "| 欄位 |\n| --- |\n| 2\\*3 與 \\[備註\\] |\n"
        let text = MarkdownImporter.attributedString(from: source)
        XCTAssertEqual(MarkdownExporter.markdown(from: text), source)
        var cell = ""
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if let table = value as? TableAttachment { cell = table.model.rows[1][0] }
        }
        XCTAssertEqual(InlineMarkdown.attributedString(from: cell).string, "2*3 與 [備註]")
    }

    func testTypingInCellUpdatesModelAndBoldToggleWritesMarkdown() {
        let view = TableCellTextView(isHeader: false)
        var latest = ""
        view.onChange = { latest = $0 }
        view.load("價格")
        view.setSelectedRange(NSRange(location: 0, length: 2))
        view.toggle(.meadBold)
        XCTAssertEqual(latest, "**價格**")
        XCTAssertEqual(view.string, "價格", "儲存格裡看不到星號")
        view.toggle(.meadBold)
        XCTAssertEqual(latest, "價格")
    }
}
