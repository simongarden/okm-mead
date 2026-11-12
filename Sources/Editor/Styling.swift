import AppKit

/// 由語意屬性（段落樣式、粗體等旗標）推導出顯示屬性（字型、顏色、段落樣式）。
/// 顯示屬性從不直接編輯，所以貼上或復原之後只要重跑一次就會一致。
@MainActor
enum Styling {
    static func restyle(_ text: NSMutableAttributedString, in range: NSRange) {
        guard text.length > 0 else { return }
        let string = text.string as NSString
        let clamped = NSIntersectionRange(range, NSRange(location: 0, length: text.length))
        var target = string.paragraphRange(for: clamped)
        // 段距取決於前後段落是不是同一組，所以相鄰段落要一起重算。
        if target.location > 0 {
            target = NSUnionRange(target, string.paragraphRange(for: NSRange(location: target.location - 1, length: 0)))
        }
        if NSMaxRange(target) < string.length {
            target = NSUnionRange(target, string.paragraphRange(for: NSRange(location: NSMaxRange(target), length: 0)))
        }

        var location = target.location
        while location < NSMaxRange(target) {
            let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
            restyleParagraph(text, range: paragraph)
            location = NSMaxRange(paragraph)
        }
    }

    private static func restyleParagraph(_ text: NSMutableAttributedString, range: NSRange) {
        // 合併段落後，整段沿用開頭的樣式。
        let style = text.blockStyle(at: range.location)
        let indent = style.isList ? text.indentLevel(at: range.location) : 0
        set(.meadBlock, style.rawValue as NSString, in: range, of: text)
        set(.meadIndent, style.isList ? indent as NSNumber : nil, in: range, of: text)
        let checked = text.attribute(.meadCheck, at: range.location, effectiveRange: nil) as? Bool ?? false
        set(.meadCheck, style == .todo ? checked as NSNumber : nil, in: range, of: text)
        if style == .code {
            let language = text.attribute(.meadCodeLanguage, at: range.location, effectiveRange: nil) as? String ?? ""
            let group = text.attribute(.meadCodeGroup, at: range.location, effectiveRange: nil) as? Int ?? 0
            set(.meadCodeLanguage, language as NSString, in: range, of: text)
            set(.meadCodeGroup, group as NSNumber, in: range, of: text)
        } else {
            set(.meadCodeLanguage, nil, in: range, of: text)
            set(.meadCodeGroup, nil, in: range, of: text)
        }

        let paragraphStyle = Theme.paragraphStyle(for: style, indent: indent).mutableCopy() as! NSMutableParagraphStyle
        if style == .code || style == .quote, !continuesGroup(text, after: range, style: style) {
            paragraphStyle.paragraphSpacing = Theme.groupTrailingSpacing
        }
        // 清單項目的段距固定：項目後面有沒有下一項都在同一個位置，新項目從空行變成有字時才不會位移。
        // 清單和後面內容的距離，由後面那一段在上方補足。
        if !style.isList, range.location > 0, text.blockStyle(at: range.location - 1).isList {
            paragraphStyle.paragraphSpacingBefore = max(paragraphStyle.paragraphSpacingBefore, Theme.groupTrailingSpacing - 4)
        }
        set(.paragraphStyle, paragraphStyle, in: range, of: text)

        // 先收集再修改：邊列舉邊改屬性會改變列舉中的區段。
        var runs: [(range: NSRange, attributes: [NSAttributedString.Key: Any])] = []
        text.enumerateAttributes(in: range) { attributes, runRange, _ in runs.append((runRange, attributes)) }
        for run in runs {
            let display = displayAttributes(style: style, semantic: run.attributes)
            for key in derivedKeys {
                set(key, display[key] as? NSObject, in: run.range, of: text)
            }
        }
    }

    /// 由語意屬性推導出來、不允許直接設定的顯示屬性。
    private static let derivedKeys: [NSAttributedString.Key] = [.font, .foregroundColor, .strikethroughStyle, .backgroundColor]

    /// 只在現值不同時才寫入。每寫入一次，文字系統就會把該範圍當成「被修改過」而重新排版，
    /// 所以打字時若每次都重寫沒有變化的屬性，畫面會跟著跳動。
    private static func set(
        _ key: NSAttributedString.Key, _ value: NSObject?, in range: NSRange, of text: NSMutableAttributedString
    ) {
        guard range.length > 0 else { return }
        var differs = false
        text.enumerateAttribute(key, in: range) { current, _, stop in
            let same: Bool
            switch (current as? NSObject, value) {
            case (nil, nil): same = true
            case let (existing?, wanted?): same = existing.isEqual(wanted)
            default: same = false
            }
            if !same { differs = true; stop.pointee = true }
        }
        guard differs else { return }
        if let value {
            text.addAttribute(key, value: value, range: range)
        } else {
            text.removeAttribute(key, range: range)
        }
    }

    private static func continuesGroup(_ text: NSAttributedString, after range: NSRange, style: BlockStyle) -> Bool {
        let next = NSMaxRange(range)
        guard next < text.length else { return false }
        let nextStyle = text.blockStyle(at: next)
        guard nextStyle == style else { return false }
        if style == .code {
            let current = text.attribute(.meadCodeGroup, at: range.location, effectiveRange: nil) as? Int
            let following = text.attribute(.meadCodeGroup, at: next, effectiveRange: nil) as? Int
            return current == following
        }
        return true
    }

    /// 也用來設定輸入中的屬性（typing attributes），讓還沒進入文字儲存區的字先以正確樣式顯示。
    static func displayAttributes(
        style: BlockStyle, semantic: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        let inlineCode = semantic[.meadInlineCode] as? Bool == true
        let raw = semantic[.meadRawInline] != nil
        var attributes: [NSAttributedString.Key: Any] = [
            .font: Theme.font(
                for: style,
                bold: semantic[.meadBold] as? Bool == true,
                italic: semantic[.meadItalic] as? Bool == true,
                inlineCode: inlineCode
            ),
            .foregroundColor: raw ? OKMPalette.textMuted : Theme.textColor(for: style),
        ]
        if semantic[.meadStrike] as? Bool == true {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if (inlineCode && style != .code) || raw {
            attributes[.backgroundColor] = Theme.pageSunken
        }
        return attributes
    }
}
