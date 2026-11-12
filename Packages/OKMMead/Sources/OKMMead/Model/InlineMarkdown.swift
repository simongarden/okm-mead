// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit
import Markdown

/// 表格儲存格的內容：資料模型存行內 Markdown（多行以換行分隔），畫面上顯示成帶語意屬性的文字。
@MainActor
enum InlineMarkdown {
    /// 儲存格的 Markdown → 語意屬性字串（`.meadBold`、`.link` 等，還沒有字型與顏色）。
    static func attributedString(from markdown: String) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for (index, line) in markdown.components(separatedBy: "\n").enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n")) }
            result.append(MarkdownImporter.cellInlines(from: line))
        }
        return result
    }

    static func markdown(from text: NSAttributedString) -> String {
        let string = text.string as NSString
        var lines: [String] = []
        var location = 0
        while location <= string.length {
            let rest = NSRange(location: location, length: string.length - location)
            let newline = string.range(of: "\n", options: [], range: rest)
            let end = newline.location == NSNotFound ? string.length : newline.location
            lines.append(MarkdownExporter.inlineMarkdown(of: text, in: NSRange(location: location, length: end - location)))
            if newline.location == NSNotFound { break }
            location = end + 1
        }
        return lines.joined(separator: "\n")
    }
}
