// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit
import SwiftUI

/// 編輯器的排版與版面常數。顏色一律取自 `Palette`（由使用端注入）。
enum Theme {
    static let pageWidth: CGFloat = 760
    static let pageHorizontalPadding: CGFloat = 72
    static let pageTopPadding: CGFloat = 64
    static let pageBottomPadding: CGFloat = 96
    /// 紙張與視窗邊緣的最小距離，也是邊界樣式標籤所在的位置。
    static let canvasMargin: CGFloat = 28
    static let pageCornerRadius: CGFloat = 6
    static let listIndentStep: CGFloat = 24

    static var textColumnWidth: CGFloat { pageWidth - pageHorizontalPadding * 2 }

    static func fontSize(for style: BlockStyle) -> CGFloat {
        switch style {
        case .title: 28
        case .heading: 21
        case .subheading: 17
        case .code: 13
        default: 15
        }
    }

    static func font(for style: BlockStyle, bold: Bool, italic: Bool, inlineCode: Bool) -> NSFont {
        let size = fontSize(for: style)
        if style == .code || inlineCode {
            let codeSize = inlineCode && style != .code ? size - 1 : size
            return .monospacedSystemFont(ofSize: codeSize, weight: bold ? .semibold : .regular)
        }
        let weight: NSFont.Weight = switch style {
        case .title: .bold
        case .heading, .subheading: .semibold
        // 中文字的 semibold 和 regular 差異太小，內文的粗體直接用 bold。
        default: bold ? .bold : .regular
        }
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard italic else { return base }
        // 中文字型沒有斜體；用變形矩陣把字傾斜，中英文的斜度才會一致。
        let slant = AffineTransform(m11: 1, m12: 0, m21: italicSlant, m22: 1, tX: 0, tY: 0)
        return NSFont(descriptor: base.fontDescriptor, textTransform: slant) ?? base
    }

    static let italicSlant: CGFloat = 0.2

    static func textColor(for style: BlockStyle) -> NSColor {
        style == .quote ? Palette.textMuted : Palette.text
    }

    /// 段落間距以「上方多、下方少」分層：標題上方留白明顯大於下方，讓標題貼近它帶領的內容。
    static func paragraphStyle(for style: BlockStyle, indent: Int) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        let size = fontSize(for: style)
        paragraph.lineHeightMultiple = style.isHeading ? 1.2 : 1.45
        switch style {
        case .title:
            paragraph.paragraphSpacingBefore = 4
            paragraph.paragraphSpacing = 14
        case .heading:
            paragraph.paragraphSpacingBefore = 26
            paragraph.paragraphSpacing = 8
        case .subheading:
            paragraph.paragraphSpacingBefore = 18
            paragraph.paragraphSpacing = 6
        case .body:
            paragraph.paragraphSpacing = size * 0.7
        case .quote:
            paragraph.paragraphSpacing = size * 0.7
            paragraph.firstLineHeadIndent = listIndentStep
            paragraph.headIndent = listIndentStep
        case .bullet, .numbered, .todo:
            paragraph.paragraphSpacing = 4
            let offset = listIndentStep * CGFloat(indent + 1)
            paragraph.firstLineHeadIndent = offset
            paragraph.headIndent = offset
        case .code:
            paragraph.lineHeightMultiple = 1.3
            paragraph.firstLineHeadIndent = 14
            paragraph.headIndent = 14
            paragraph.tailIndent = -14
        }
        return paragraph
    }

    /// 連續的清單或程式碼段落之間不留段距，但整組的最後一段要和下一個區塊隔開。
    static let groupTrailingSpacing: CGFloat = 12
}

extension Color {
    static let okmBackground = Color(nsColor: Theme.canvas)
    static let okmSurface = Color(nsColor: Theme.page)
    static let okmSurfaceSunken = Color(nsColor: Theme.pageSunken)
    static let okmSidebarTint = Color(nsColor: Theme.sidebarTint)
    static let okmBorder = Color(nsColor: Palette.border)
    static let okmBorderStrong = Color(nsColor: Palette.borderStrong)
    static let okmText = Color(nsColor: Palette.text)
    static let okmTextMuted = Color(nsColor: Palette.textMuted)
    static let okmPrimary = Color(nsColor: Palette.primary)
    static let okmOnPrimary = Color(nsColor: Palette.onPrimary)
    static let okmAccent = Color(nsColor: Palette.accent)
    static let okmDanger = Color(nsColor: Palette.danger)
    /// 選取列與表頭列的淺底。
    static let okmTint = Color(nsColor: Theme.tint)
    static let okmOnTint = Color(nsColor: Theme.onTint)
}

extension Theme {
    /// 紙張後面的畫布。
    static var canvas: NSColor { MeadConfiguration.appearance.canvas }
    /// 紙張。
    static var page: NSColor { MeadConfiguration.appearance.page }
    /// 紙張上的凹陷區塊：程式碼、行內程式碼、表格把手。
    static var pageSunken: NSColor { MeadConfiguration.appearance.pageSunken }
    /// 大綱側欄的底色。
    static var sidebarTint: NSColor { MeadConfiguration.appearance.sidebar }
    static var tint: NSColor { MeadConfiguration.appearance.tint }
    static var onTint: NSColor { MeadConfiguration.appearance.onTint }
}

/// 編輯器取用的語意色；實際的值由使用端經 `MeadConfiguration.appearance` 提供。
enum Palette {
    static var border: NSColor { MeadConfiguration.appearance.border }
    static var borderStrong: NSColor { MeadConfiguration.appearance.borderStrong }
    static var text: NSColor { MeadConfiguration.appearance.text }
    static var textMuted: NSColor { MeadConfiguration.appearance.textMuted }
    static var primary: NSColor { MeadConfiguration.appearance.primary }
    static var onPrimary: NSColor { MeadConfiguration.appearance.onPrimary }
    static var accent: NSColor { MeadConfiguration.appearance.accent }
    static var focusRing: NSColor { MeadConfiguration.appearance.focusRing }
    static var warning: NSColor { MeadConfiguration.appearance.warning }
    static var danger: NSColor { MeadConfiguration.appearance.danger }
    static var shadow: NSColor { MeadConfiguration.appearance.shadow }
}
