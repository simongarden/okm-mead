// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit
import Markdown

/// Markdown 文字 → 編輯器用的屬性字串。產生的字串還沒有字型與段落樣式，由 `Styling.restyle` 補上。
@MainActor
struct MarkdownImporter {
    private let output = NSMutableAttributedString()
    private var codeGroup = 0

    static func attributedString(from markdown: String) -> NSMutableAttributedString {
        var importer = MarkdownImporter()
        // 檔頭的 YAML front matter 不是 Markdown：先拿出來原樣保留，否則會被當成分隔線與標題。
        let (frontMatter, body) = splitFrontMatter(markdown)
        if let frontMatter { importer.appendCode(frontMatter, language: MarkdownRaw.blockLanguage) }
        let document = Document(parsing: body)
        for block in document.children {
            importer.append(block: block, indent: 0, quoted: false)
        }
        // 段落之間用換行分隔，結尾不留空段落。
        if importer.output.string.hasSuffix("\n") {
            importer.output.deleteCharacters(in: NSRange(location: importer.output.length - 1, length: 1))
        }
        Styling.restyle(importer.output, in: NSRange(location: 0, length: importer.output.length))
        return importer.output
    }

    /// 檔案以單獨一行 `---` 開頭、之後另有一行 `---` 或 `...` 收尾時，這一段是 front matter。
    static func splitFrontMatter(_ markdown: String) -> (frontMatter: String?, body: String) {
        let lines = markdown.components(separatedBy: "\n")
        guard lines.count > 2, lines[0] == "---",
              let end = lines.dropFirst().firstIndex(where: { $0 == "---" || $0 == "..." }), end > 1 else { return (nil, markdown) }
        return (lines[0...end].joined(separator: "\n"), lines[(end + 1)...].joined(separator: "\n"))
    }

    // MARK: 區塊

    private mutating func append(block: any Markup, indent: Int, quoted: Bool) {
        switch block {
        case let heading as Heading:
            let style: BlockStyle = heading.level == 1 ? .title : heading.level == 2 ? .heading : .subheading
            appendParagraph(inlines(of: heading), style: style, extra: heading.level > 3 ? [.meadHeadingLevel: heading.level] : [:])
        case let paragraph as Paragraph:
            // 獨立一段的圖片當成區塊顯示；夾在文字中間的圖片維持原樣保留。
            if !quoted, paragraph.childCount == 1, let image = paragraph.child(at: 0) as? Markdown.Image,
               let source = image.source, !source.isEmpty, (image.title ?? "").isEmpty {
                appendAttachment(ImageAttachment(model: ImageModel(alt: image.plainText, path: source)))
                return
            }
            appendParagraph(inlines(of: paragraph), style: quoted ? .quote : .body)
        case let quote as BlockQuote:
            for child in quote.children { append(block: child, indent: indent, quoted: true) }
        case let list as UnorderedList:
            appendList(items: Array(list.listItems), style: .bullet, indent: indent)
        case let list as OrderedList:
            appendList(items: Array(list.listItems), style: .numbered, indent: indent)
        case let code as CodeBlock:
            if code.language?.lowercased() == "mermaid" {
                let source = code.code.trimmingCharacters(in: .newlines)
                appendAttachment(DiagramAttachment(model: DiagramModel(source: source)))
            } else {
                appendCode(code.code, language: code.language ?? "")
            }
        case let table as Markdown.Table:
            var rows: [[String]] = [Array(table.head.cells.map(Self.cellText))]
            for row in table.body.rows { rows.append(Array(row.cells.map(Self.cellText))) }
            appendAttachment(TableAttachment(model: TableModel(rows: rows)))
        case is ThematicBreak:
            appendAttachment(DividerAttachment())
        case let html as HTMLBlock:
            appendCode(html.rawHTML, language: MarkdownRaw.blockLanguage)
        default:
            appendCode(block.format(), language: MarkdownRaw.blockLanguage)
        }
    }

    private mutating func appendList(items: [ListItem], style: BlockStyle, indent: Int) {
        for item in items {
            var isFirstParagraph = true
            for child in item.children {
                if let paragraph = child as? Paragraph {
                    var attributes: [NSAttributedString.Key: Any] = [.meadIndent: indent]
                    var itemStyle = style
                    if isFirstParagraph, let checkbox = item.checkbox {
                        itemStyle = .todo
                        attributes[.meadCheck] = checkbox == .checked
                    }
                    appendParagraph(inlines(of: paragraph), style: itemStyle, extra: attributes)
                    isFirstParagraph = false
                } else if child is UnorderedList || child is OrderedList {
                    append(block: child, indent: indent + 1, quoted: false)
                } else {
                    append(block: child, indent: indent, quoted: false)
                }
            }
            if item.childCount == 0 {
                appendParagraph(NSAttributedString(), style: style, extra: [.meadIndent: indent])
            }
        }
    }

    private mutating func appendParagraph(
        _ content: NSAttributedString, style: BlockStyle, extra: [NSAttributedString.Key: Any] = [:]
    ) {
        let paragraph = NSMutableAttributedString(attributedString: content)
        paragraph.append(NSAttributedString(string: "\n"))
        var attributes = extra
        attributes[.meadBlock] = style.rawValue
        paragraph.addAttributes(attributes, range: NSRange(location: 0, length: paragraph.length))
        output.append(paragraph)
    }

    private mutating func appendCode(_ code: String, language: String) {
        codeGroup += 1
        var lines = code.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        for line in lines.isEmpty ? [""] : lines {
            appendParagraph(NSAttributedString(string: line), style: .code,
                            extra: [.meadCodeLanguage: language, .meadCodeGroup: codeGroup])
        }
    }

    private mutating func appendAttachment(_ attachment: NSTextAttachment) {
        output.append(Self.paragraph(for: attachment))
    }

    static func paragraph(for attachment: NSTextAttachment) -> NSAttributedString {
        let paragraph = NSMutableAttributedString(attachment: attachment)
        paragraph.append(NSAttributedString(string: "\n"))
        paragraph.addAttribute(.meadBlock, value: BlockStyle.body.rawValue,
                               range: NSRange(location: 0, length: paragraph.length))
        return paragraph
    }

    /// 儲存格保留行內的 Markdown（粗體、行內程式碼、連結），存檔時才不會被抹平成純文字。
    /// 經過和內文相同的匯入、匯出，原本就是字面的星號或方括號才會維持跳脫。
    private static func cellText(_ cell: Markdown.Table.Cell) -> String {
        let inlines = MarkdownImporter().inlines(of: cell)
        let text = MarkdownExporter.inlineMarkdown(of: inlines, in: NSRange(location: 0, length: inlines.length))
        return text.replacingOccurrences(of: "<br>", with: "\n").replacingOccurrences(of: "<br/>", with: "\n")
    }

    /// 把儲存格裡的一行 Markdown 解析成語意屬性字串。
    /// 包成一格表格再解析，結果才和它在檔案裡的意思一致（例如開頭的「1.」不會被當成清單）。
    static func cellInlines(from line: String) -> NSAttributedString {
        guard !line.isEmpty else { return NSAttributedString() }
        let escaped = line.replacingOccurrences(of: "|", with: "\\|")
        let document = Document(parsing: "| \(escaped) |\n| --- |")
        guard let table = document.child(at: 0) as? Markdown.Table, let cell = Array(table.head.cells).first else {
            return NSAttributedString(string: line)
        }
        return MarkdownImporter().inlines(of: cell)
    }

    // MARK: 行內

    private func inlines(of container: any Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in container.children {
            appendInline(child, attributes: [:], to: result)
        }
        return result
    }

    private func appendInline(
        _ node: any Markup, attributes: [NSAttributedString.Key: Any], to result: NSMutableAttributedString
    ) {
        func recurse(adding key: NSAttributedString.Key, _ value: Any) {
            var nested = attributes
            nested[key] = value
            for child in node.children { appendInline(child, attributes: nested, to: result) }
        }

        switch node {
        case let text as Markdown.Text:
            result.append(NSAttributedString(string: text.string, attributes: attributes))
        case is Strong:
            recurse(adding: .meadBold, true)
        case is Emphasis:
            recurse(adding: .meadItalic, true)
        case is Strikethrough:
            recurse(adding: .meadStrike, true)
        case let code as InlineCode:
            var nested = attributes
            nested[.meadInlineCode] = true
            result.append(NSAttributedString(string: code.code, attributes: nested))
        case let link as Markdown.Link:
            if let destination = link.destination, let url = URL(string: destination) {
                recurse(adding: .link, url)
            } else {
                for child in node.children { appendInline(child, attributes: attributes, to: result) }
            }
        case let image as Markdown.Image:
            let label = image.plainText.isEmpty ? String(localized: "圖片", bundle: .module) : String(localized: "圖片：\(image.plainText)", bundle: .module)
            appendRaw(display: "〔\(label)〕", markdown: image.format(), attributes: attributes, to: result)
        case let html as InlineHTML:
            appendRaw(display: html.rawHTML, markdown: html.rawHTML, attributes: attributes, to: result)
        case is SoftBreak:
            // 中文字之間的換行不該變成空格。
            let previous = result.string.unicodeScalars.last
            if let previous, !Self.isCJK(previous) {
                result.append(NSAttributedString(string: " ", attributes: attributes))
            }
        case is LineBreak:
            result.append(NSAttributedString(string: "\u{2028}", attributes: attributes))
        default:
            if node.childCount > 0 {
                for child in node.children { appendInline(child, attributes: attributes, to: result) }
            } else {
                appendRaw(display: node.format(), markdown: node.format(), attributes: attributes, to: result)
            }
        }
    }

    private func appendRaw(
        display: String, markdown: String, attributes: [NSAttributedString.Key: Any],
        to result: NSMutableAttributedString
    ) {
        var nested = attributes
        nested[.meadRawInline] = markdown
        result.append(NSAttributedString(string: display, attributes: nested))
    }

    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x2E80...0x9FFF, 0xF900...0xFAFF, 0xFF00...0xFFEF, 0x20000...0x2FA1F: true
        default: false
        }
    }
}
