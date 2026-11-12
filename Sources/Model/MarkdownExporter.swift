import AppKit

/// 編輯器內容 → Markdown。輸出力求和手寫的一樣整齊：ATX 標題、`-` 清單、圍欄程式碼。
@MainActor
enum MarkdownExporter {
    private enum Block {
        case text(String)
        case listItem(String, topLevelNumbered: Bool?)
        case quote(String)
        case code(lines: [String], language: String, group: Int)
    }

    static func markdown(from text: NSAttributedString) -> String {
        var blocks: [Block] = []
        var counters: [Int: Int] = [:]
        let string = text.string as NSString
        var location = 0

        func resetCounters(deeperThan level: Int) {
            for key in counters.keys where key > level { counters[key] = nil }
        }

        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            location = NSMaxRange(paragraphRange)
            var contentRange = paragraphRange
            if contentRange.length > 0, string.character(at: NSMaxRange(contentRange) - 1) == 0x0A {
                contentRange.length -= 1
            }
            let style = text.blockStyle(at: paragraphRange.location)

            if style == .code {
                counters.removeAll()
                let line = string.substring(with: contentRange)
                let language = text.attribute(.meadCodeLanguage, at: paragraphRange.location, effectiveRange: nil) as? String ?? ""
                let group = text.attribute(.meadCodeGroup, at: paragraphRange.location, effectiveRange: nil) as? Int ?? 0
                if case .code(let lines, let previousLanguage, let previousGroup) = blocks.last,
                   previousGroup == group, previousLanguage == language {
                    blocks[blocks.count - 1] = .code(lines: lines + [line], language: language, group: group)
                } else {
                    blocks.append(.code(lines: [line], language: language, group: group))
                }
                continue
            }

            // 表格、流程圖等區塊各自成段；同一段落裡若還有文字，前後拆成獨立段落。
            for piece in pieces(of: text, in: contentRange) {
                switch piece {
                case .attachment(let markdown):
                    counters.removeAll()
                    blocks.append(.text(markdown))
                case .inline(let range):
                    let isEmpty = string.substring(with: range).trimmingCharacters(in: .whitespaces).isEmpty
                    if isEmpty && !style.isList { continue }
                    let inline = inlineMarkdown(of: text, in: range)
                    switch style {
                    case .title, .heading, .subheading:
                        counters.removeAll()
                        let hashes = String(repeating: "#", count: style.headingLevel ?? 1)
                        blocks.append(.text("\(hashes) \(inline.replacingOccurrences(of: "\\\n", with: " "))"))
                    case .quote:
                        counters.removeAll()
                        blocks.append(.quote(prefixLines(protectLineStart(inline), first: "> ", rest: "> ")))
                    case .bullet, .numbered, .todo:
                        let level = text.indentLevel(at: paragraphRange.location)
                        resetCounters(deeperThan: level)
                        let indent = String(repeating: "    ", count: level)
                        var marker = "- "
                        if style == .numbered {
                            counters[level, default: 0] += 1
                            marker = "\(counters[level] ?? 1). "
                        } else {
                            counters[level] = nil
                            if style == .todo {
                                let checked = text.attribute(.meadCheck, at: paragraphRange.location, effectiveRange: nil) as? Bool ?? false
                                marker += checked ? "[x] " : "[ ] "
                            }
                        }
                        let continuation = indent + String(repeating: " ", count: marker.count)
                        blocks.append(.listItem(
                            prefixLines(protectLineStart(inline), first: indent + marker, rest: continuation),
                            topLevelNumbered: level == 0 ? style == .numbered : nil
                        ))
                    case .body, .code:
                        counters.removeAll()
                        blocks.append(.text(protectLineStart(inline)))
                    }
                }
            }
        }

        var output = ""
        for (index, block) in blocks.enumerated() {
            if index > 0 {
                switch (blocks[index - 1], block) {
                case (.listItem(_, let previous), .listItem(_, let current)):
                    // 項目清單緊接編號清單時空一行，讀原始檔的人才看得出是兩份清單。
                    output += previous != nil && current != nil && previous != current ? "\n\n" : "\n"
                case (.quote, .quote): output += "\n>\n"
                default: output += "\n\n"
                }
            }
            switch block {
            case .text(let value), .listItem(let value, _), .quote(let value):
                output += value
            case .code(let lines, let language, _):
                let body = lines.joined(separator: "\n")
                if language == MarkdownRaw.blockLanguage {
                    output += body
                } else {
                    let fence = body.contains("```") ? "````" : "```"
                    output += "\(fence)\(language)\n\(body)\n\(fence)"
                }
            }
        }
        return output.isEmpty ? "" : output + "\n"
    }

    // MARK: 區塊

    private enum Piece {
        case inline(NSRange)
        case attachment(String)
    }

    private static func pieces(of text: NSAttributedString, in range: NSRange) -> [Piece] {
        var result: [Piece] = []
        var cursor = range.location
        text.enumerateAttribute(.attachment, in: range) { value, attachmentRange, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            if attachmentRange.location > cursor {
                result.append(.inline(NSRange(location: cursor, length: attachmentRange.location - cursor)))
            }
            if let markdown = markdown(for: attachment) { result.append(.attachment(markdown)) }
            cursor = NSMaxRange(attachmentRange)
        }
        if cursor < NSMaxRange(range) || result.isEmpty {
            result.append(.inline(NSRange(location: cursor, length: NSMaxRange(range) - cursor)))
        }
        return result
    }

    private static func markdown(for attachment: NSTextAttachment) -> String? {
        switch attachment {
        case let table as TableAttachment: table.model.markdown
        case let diagram as DiagramAttachment: "```mermaid\n\(diagram.model.source)\n```"
        case let image as ImageAttachment:
            "![\(escape(image.model.alt))](\(escapeDestination(image.model.path)))"
        case is DividerAttachment: "---"
        default: nil
        }
    }

    private static func prefixLines(_ text: String, first: String, rest: String) -> String {
        let lines = text.components(separatedBy: "\n")
        return lines.enumerated().map { ($0.offset == 0 ? first : rest) + $0.element }.joined(separator: "\n")
    }

    /// 內文開頭若剛好長得像標題、清單或引言的記號，加上反斜線，避免存檔後變成別的樣式。
    private static func protectLineStart(_ line: String) -> String {
        let trimmed = String(line.drop(while: { $0 == " " || $0 == "\t" }))
        guard let first = trimmed.first else { return trimmed }
        if first == "#" || first == ">" { return "\\" + trimmed }
        if "-+=".contains(first) {
            let rest = trimmed.dropFirst()
            if rest.isEmpty || rest.first == " " || rest.allSatisfy({ $0 == first || $0 == " " }) {
                return "\\" + trimmed
            }
        }
        if first.isNumber, let delimiter = trimmed.firstIndex(where: { !$0.isNumber }),
           trimmed[delimiter] == "." || trimmed[delimiter] == ")" {
            let after = trimmed.index(after: delimiter)
            if after == trimmed.endIndex || trimmed[after] == " " {
                return String(trimmed[..<delimiter]) + "\\" + String(trimmed[delimiter...])
            }
        }
        return trimmed
    }

    // MARK: 行內

    private struct Run {
        var text: String
        var bold = false
        var italic = false
        var strike = false
        var code = false
        var link: String?
        var raw: String?

        var isEmphasized: Bool { bold || italic || strike }
    }

    private static func inlineMarkdown(of text: NSAttributedString, in range: NSRange) -> String {
        var runs: [Run] = []
        text.enumerateAttributes(in: range) { attributes, runRange, _ in
            var run = Run(text: (text.string as NSString).substring(with: runRange))
            run.bold = attributes[.meadBold] as? Bool ?? false
            run.italic = attributes[.meadItalic] as? Bool ?? false
            run.strike = attributes[.meadStrike] as? Bool ?? false
            run.code = attributes[.meadInlineCode] as? Bool ?? false
            run.raw = attributes[.meadRawInline] as? String
            if let url = attributes[.link] as? URL {
                run.link = url.absoluteString
            } else if let string = attributes[.link] as? String {
                run.link = string
            }
            runs.append(run)
        }
        runs = hoistEdges(runs)

        var output = ""
        var open: (link: String?, bold: Bool, italic: Bool, strike: Bool) = (nil, false, false, false)

        func close(downTo level: Int) {
            if level <= 3, open.strike { output += "~~"; open.strike = false }
            if level <= 2, open.italic { output += "*"; open.italic = false }
            if level <= 1, open.bold { output += "**"; open.bold = false }
            if level <= 0, let link = open.link { output += "](\(escapeDestination(link)))"; open.link = nil }
        }

        for run in runs {
            let firstChange: Int =
                open.link != run.link ? 0 : open.bold != run.bold ? 1 : open.italic != run.italic ? 2
                : open.strike != run.strike ? 3 : 4
            close(downTo: firstChange)
            if firstChange <= 0, let link = run.link { output += "["; open.link = link }
            if firstChange <= 1, run.bold { output += "**"; open.bold = true }
            if firstChange <= 2, run.italic { output += "*"; open.italic = true }
            if firstChange <= 3, run.strike { output += "~~"; open.strike = true }

            if let raw = run.raw {
                output += raw
            } else if run.code {
                output += codeSpan(run.text)
            } else {
                output += escape(run.text).replacingOccurrences(of: "\u{2028}", with: "\\\n")
            }
        }
        close(downTo: 0)
        return output
    }

    /// 強調記號緊貼空白，或夾在全形標點與文字之間時，Markdown 不會把它當成強調。
    /// 把強調範圍兩端的空白與標點移到記號外面，顯示結果幾乎相同，存檔後也不會露出星號。
    private static func hoistEdges(_ runs: [Run]) -> [Run] {
        var result: [Run] = []
        for (index, run) in runs.enumerated() {
            guard run.isEmphasized, run.raw == nil, !run.code else {
                result.append(run)
                continue
            }
            let scalars = Array(run.text.unicodeScalars)
            let previousIsEmphasized = index > 0 && runs[index - 1].isEmphasized
            let nextIsEmphasized = index + 1 < runs.count && runs[index + 1].isEmphasized
            var start = 0
            var end = scalars.count
            func movable(_ scalar: Unicode.Scalar) -> Bool {
                CharacterSet.whitespaces.contains(scalar) || CharacterSet.punctuationCharacters.contains(scalar)
                    || CharacterSet.symbols.contains(scalar) || scalar == "\u{2028}"
            }
            if !previousIsEmphasized { while start < end, movable(scalars[start]) { start += 1 } }
            if !nextIsEmphasized { while end > start, movable(scalars[end - 1]) { end -= 1 } }

            func plain(_ slice: ArraySlice<Unicode.Scalar>) -> Run {
                var copy = run
                copy.text = String(String.UnicodeScalarView(slice))
                copy.bold = false
                copy.italic = false
                copy.strike = false
                return copy
            }
            if start > 0 { result.append(plain(scalars[0..<start])) }
            if end > start {
                var core = run
                core.text = String(String.UnicodeScalarView(scalars[start..<end]))
                result.append(core)
            }
            if end < scalars.count { result.append(plain(scalars[end...])) }
        }
        return result
    }

    private static func codeSpan(_ code: String) -> String {
        var longest = 0
        var current = 0
        for character in code {
            current = character == "`" ? current + 1 : 0
            longest = max(longest, current)
        }
        let fence = String(repeating: "`", count: longest + 1)
        let padding = code.hasPrefix("`") || code.hasSuffix("`") ? " " : ""
        return fence + padding + code + padding + fence
    }

    private static func escapeDestination(_ url: String) -> String {
        url.contains(" ") || url.contains("(") || url.contains(")") ? "<\(url)>" : url
    }

    private static func escape(_ text: String) -> String {
        let characters = Array(text)
        var output = ""
        for (index, character) in characters.enumerated() {
            switch character {
            case "\\", "`", "*", "[", "]", "<":
                output += "\\\(character)"
            case "_":
                // 單字中間的底線（例如 file_name）不會被當成強調，不必加反斜線。
                let before = index > 0 && (characters[index - 1].isLetter || characters[index - 1].isNumber)
                let after = index + 1 < characters.count && (characters[index + 1].isLetter || characters[index + 1].isNumber)
                output += before && after ? "_" : "\\_"
            case "~":
                let doubled = (index + 1 < characters.count && characters[index + 1] == "~")
                    || (index > 0 && characters[index - 1] == "~")
                output += doubled ? "\\~" : "~"
            default:
                output.append(character)
            }
        }
        return output
    }
}
