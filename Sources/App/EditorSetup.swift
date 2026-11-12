import AppKit
import OKMMead
import SwiftUI

/// 編輯核心（`Packages/OKMMead`）在這個 App 裡的設定：OKM 色票與 App 內附的 Mermaid。
@MainActor
enum EditorSetup {
    private static var configured = false

    /// 建立第一個編輯器之前呼叫一次。
    static func configure() {
        guard !configured else { return }
        configured = true
        MeadConfiguration.appearance = MeadAppearance(
            canvas: AppTheme.canvas, page: AppTheme.page, pageSunken: AppTheme.pageSunken, sidebar: AppTheme.sidebarTint,
            border: OKMPalette.border, borderStrong: OKMPalette.borderStrong,
            text: OKMPalette.text, textMuted: OKMPalette.textMuted,
            primary: OKMPalette.primary, onPrimary: OKMPalette.onPrimary, accent: OKMPalette.accent,
            focusRing: OKMPalette.focusRing, warning: OKMPalette.warning, danger: OKMPalette.danger,
            tint: AppTheme.tint, onTint: AppTheme.onTint, selection: AppTheme.selection, shadow: OKMPalette.navy950
        )
        MeadConfiguration.mermaidScript = Bundle.main.url(forResource: "mermaid.min", withExtension: "js")
    }
}

/// 這個 App 的底色。語意色取自 `OKMPalette`；以下幾層是經使用者確認的例外。
enum AppTheme {
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

    /// 選取列與表頭列的品牌淺底；深色外觀改用較深的海軍藍。
    static let tint = NSColor(name: "OKMTint") { isDark($0) ? OKMPalette.navy700 : OKMPalette.navy100 }

    /// `tint` 底上的文字：淺色用品牌海軍藍；深色用一般文字色，否則會比沒選取的項目還暗。
    static let onTint = NSColor(name: "OKMOnTint") { isDark($0) ? OKMPalette.text : OKMPalette.primary }

    static let selection = NSColor(name: "OKMSelection") { isDark($0) ? OKMPalette.navy600 : OKMPalette.navy200 }
}

extension Color {
    static let okmAccent = Color(nsColor: OKMPalette.accent)
}
