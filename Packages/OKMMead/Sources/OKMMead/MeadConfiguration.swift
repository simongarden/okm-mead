// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit

/// 編輯器用到的語意色。這個套件本身不帶品牌色：預設值是系統色，使用端在啟動時換成自己的色票。
public struct MeadAppearance: Sendable {
    /// 紙張後面的畫布。
    public var canvas: NSColor
    /// 紙張。
    public var page: NSColor
    /// 紙張上的凹陷區塊：程式碼、行內程式碼、表格把手。
    public var pageSunken: NSColor
    /// 大綱側欄的底色。
    public var sidebar: NSColor
    public var border: NSColor
    public var borderStrong: NSColor
    public var text: NSColor
    public var textMuted: NSColor
    /// 主要動作與「已確定」的狀態：游標、已勾選的待辦方框、主要按鈕。
    public var primary: NSColor
    public var onPrimary: NSColor
    /// 連結文字。
    public var accent: NSColor
    /// 區塊（表格、流程圖、圖片）被選取時的外框。
    public var focusRing: NSColor
    public var warning: NSColor
    public var danger: NSColor
    /// 表頭列、目前大綱項目、樣式標籤 hover 的淺底，以及其上的文字。
    public var tint: NSColor
    public var onTint: NSColor
    /// 文字選取範圍的底色；nil 時沿用系統的選取色。
    public var selection: NSColor?
    /// 紙張的陰影。
    public var shadow: NSColor

    public init(
        canvas: NSColor, page: NSColor, pageSunken: NSColor, sidebar: NSColor, border: NSColor, borderStrong: NSColor,
        text: NSColor, textMuted: NSColor, primary: NSColor, onPrimary: NSColor, accent: NSColor, focusRing: NSColor,
        warning: NSColor, danger: NSColor, tint: NSColor, onTint: NSColor, selection: NSColor? = nil, shadow: NSColor = .shadowColor
    ) {
        self.canvas = canvas; self.page = page; self.pageSunken = pageSunken; self.sidebar = sidebar
        self.border = border; self.borderStrong = borderStrong; self.text = text; self.textMuted = textMuted
        self.primary = primary; self.onPrimary = onPrimary; self.accent = accent; self.focusRing = focusRing
        self.warning = warning; self.danger = danger; self.tint = tint; self.onTint = onTint
        self.selection = selection; self.shadow = shadow
    }

    /// 只用系統色的預設外觀。
    public static let system = MeadAppearance(
        canvas: .windowBackgroundColor, page: .textBackgroundColor, pageSunken: .quaternarySystemFill, sidebar: .windowBackgroundColor,
        border: .separatorColor, borderStrong: .tertiaryLabelColor, text: .labelColor, textMuted: .secondaryLabelColor,
        primary: .labelColor, onPrimary: .textBackgroundColor, accent: .linkColor, focusRing: .keyboardFocusIndicatorColor,
        warning: .systemOrange, danger: .systemRed, tint: .quaternarySystemFill, onTint: .labelColor
    )
}

/// 使用端在建立任何編輯器之前設定一次。
public enum MeadConfiguration {
    // 只在 App 啟動時由主執行緒設定一次，之後唯讀；顏色會在繪圖回呼（沒有並行標註）中讀取，所以不綁在主執行緒上。
    nonisolated(unsafe) public static var appearance = MeadAppearance.system
    /// 單檔的 Mermaid 腳本（需定義全域的 `mermaid`）。這個套件不內附 Mermaid，由使用端提供；nil 時流程圖無法繪製。
    nonisolated(unsafe) public static var mermaidScript: URL?
}
