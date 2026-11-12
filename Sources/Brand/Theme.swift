import AppKit
import SwiftUI

/// 編輯器的排版與版面常數。顏色一律取自 `OKMPalette`。
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
        style == .quote ? OKMPalette.textMuted : OKMPalette.text
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
    static let okmCanvasGlass = Color(nsColor: Theme.canvasGlass)
    static let okmBorder = Color(nsColor: OKMPalette.border)
    static let okmBorderStrong = Color(nsColor: OKMPalette.borderStrong)
    static let okmText = Color(nsColor: OKMPalette.text)
    static let okmTextMuted = Color(nsColor: OKMPalette.textMuted)
    static let okmPrimary = Color(nsColor: OKMPalette.primary)
    static let okmOnPrimary = Color(nsColor: OKMPalette.onPrimary)
    static let okmAccent = Color(nsColor: OKMPalette.accent)
    static let okmDanger = Color(nsColor: OKMPalette.danger)
    /// 選取列與表頭列的品牌淺底；深色外觀改用較深的海軍藍。
    static let okmTint = Color(nsColor: Theme.tint)
    static let okmOnTint = Color(nsColor: Theme.onTint)
}

extension Theme {
    // 深色外觀的底色由使用者指定為中性色：視窗黑底、紙張深灰、側欄海軍藍玻璃。
    // 這三層不在 OKM 色票內（色票的深色底是海軍藍），是這個 App 經確認的例外；淺色外觀仍用色票。

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    /// 紙張後面的畫布，也是視窗與工具列玻璃後面的底。
    static let canvas = NSColor(name: "MeadCanvas") { isDark($0) ? .black : OKMPalette.bg }

    /// 紙張。深色時要比「半透明黑底疊在毛玻璃上」的畫布亮一階，否則紙張邊界會消失。
    static let page = NSColor(name: "MeadPage") {
        isDark($0) ? NSColor(srgbRed: 0.165, green: 0.165, blue: 0.176, alpha: 1) : OKMPalette.surface
    }

    /// 紙張上的凹陷區塊：程式碼、行內程式碼、表格把手。
    static let pageSunken = NSColor(name: "MeadPageSunken") {
        isDark($0) ? NSColor(srgbRed: 0.212, green: 0.212, blue: 0.227, alpha: 1) : OKMPalette.surfaceSunken
    }

    /// 疊在視窗底層毛玻璃上的底色。淺色是白色毛玻璃：白要夠濃，後方是深色視窗時畫布才不會變灰；
    /// 深色是黑色毛玻璃，保留較多透明。
    static let canvasGlass = NSColor(name: "MeadCanvasGlass") {
        isDark($0) ? NSColor.black.withAlphaComponent(0.3) : NSColor.white.withAlphaComponent(0.72)
    }

    /// 疊在側欄毛玻璃上的海軍藍。淺色用色階裡較深的一階，才和右邊的白色畫布分得開。
    static let sidebarTint = NSColor(name: "MeadSidebarTint") {
        isDark($0) ? OKMPalette.navy900.withAlphaComponent(0.3) : OKMPalette.navy200.withAlphaComponent(0.55)
    }

    static let tint = NSColor(name: "OKMTint") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? OKMPalette.navy700 : OKMPalette.navy100
    }

    /// `tint` 底上的文字：淺色用品牌海軍藍；深色用一般文字色，否則會比沒選取的項目還暗。
    static let onTint = NSColor(name: "OKMOnTint") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? OKMPalette.text : OKMPalette.primary
    }

    static let selection = NSColor(name: "OKMSelection") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? OKMPalette.navy600 : OKMPalette.navy200
    }
}
