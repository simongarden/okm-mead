// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit

/// 段落樣式。每一種都能無損存成 Markdown，介面上只顯示中文名稱。
public enum BlockStyle: String, CaseIterable, Sendable {
    case title, heading, subheading, body, quote, bullet, numbered, todo, code

    public var displayName: String {
        switch self {
        case .title: String(localized: "大標題", bundle: .module)
        case .heading: String(localized: "標題", bundle: .module)
        case .subheading: String(localized: "小標題", bundle: .module)
        case .body: String(localized: "內文", bundle: .module)
        case .quote: String(localized: "引言", bundle: .module)
        case .bullet: String(localized: "項目清單", bundle: .module)
        case .numbered: String(localized: "編號清單", bundle: .module)
        case .todo: String(localized: "待辦清單", bundle: .module)
        case .code: String(localized: "程式碼", bundle: .module)
        }
    }

    /// 樣式選單列出的項目；`code` 只在開啟既有檔案時出現，不讓使用者主動選。
    public static let pickable: [BlockStyle] = [.title, .heading, .subheading, .body, .quote, .bullet, .numbered, .todo]

    var isHeading: Bool { self == .title || self == .heading || self == .subheading }
    var isList: Bool { self == .bullet || self == .numbered || self == .todo }

    var headingLevel: Int? {
        switch self {
        case .title: 1
        case .heading: 2
        case .subheading: 3
        default: nil
        }
    }

    /// 在這種段落按 Return 之後，新段落的樣式。
    var styleAfterReturn: BlockStyle {
        isHeading ? .body : self
    }
}

extension NSAttributedString.Key {
    /// 值為 `BlockStyle.rawValue`，整個段落（含換行字元）一致。
    static let meadBlock = NSAttributedString.Key("OKMMeadBlock")
    /// 清單的縮排層級（Int，0 起算）。
    static let meadIndent = NSAttributedString.Key("OKMMeadIndent")
    /// 第四層以下標題的原始層級（Int，4–6）；只出現在 `subheading` 段落。畫面上和小標題一樣，存檔時維持原本的層級。
    static let meadHeadingLevel = NSAttributedString.Key("OKMMeadHeadingLevel")
    /// 待辦清單的勾選狀態（Bool）；只出現在 `todo` 段落。
    static let meadCheck = NSAttributedString.Key("OKMMeadCheck")
    /// 程式碼區塊的語言；`MarkdownRaw.blockLanguage` 表示原樣輸出、不加圍欄。
    static let meadCodeLanguage = NSAttributedString.Key("OKMMeadCodeLanguage")
    /// 同一個程式碼區塊共用的識別碼，用來分辨相鄰的兩個區塊。
    static let meadCodeGroup = NSAttributedString.Key("OKMMeadCodeGroup")
    static let meadBold = NSAttributedString.Key("OKMMeadBold")
    static let meadItalic = NSAttributedString.Key("OKMMeadItalic")
    static let meadStrike = NSAttributedString.Key("OKMMeadStrike")
    static let meadInlineCode = NSAttributedString.Key("OKMMeadInlineCode")
    /// 編輯器無法呈現的行內內容（例如圖片），值為原始 Markdown，存檔時原樣寫回。
    static let meadRawInline = NSAttributedString.Key("OKMMeadRawInline")
}

enum MarkdownRaw {
    static let blockLanguage = "\u{1}raw"
}

extension NSAttributedString {
    func blockStyle(at location: Int) -> BlockStyle {
        guard location < length, let raw = attribute(.meadBlock, at: location, effectiveRange: nil) as? String else {
            return .body
        }
        return BlockStyle(rawValue: raw) ?? .body
    }

    func flag(_ key: NSAttributedString.Key, at location: Int) -> Bool {
        guard location < length else { return false }
        return (attribute(key, at: location, effectiveRange: nil) as? Bool) ?? false
    }

    func indentLevel(at location: Int) -> Int {
        guard location < length else { return 0 }
        return (attribute(.meadIndent, at: location, effectiveRange: nil) as? Int) ?? 0
    }
}
