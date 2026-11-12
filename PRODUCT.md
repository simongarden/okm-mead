# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

（實際平台是 macOS 原生 App，僅支援 Mac。此欄位只接受 web／ios／android／adaptive，取最接近的 Apple 原生值；設計時依 macOS 的人機介面慣例，不套用 iPhone 的觸控與導覽規則。）

## Stack

使用者指定：Xcode、Swift 6（嚴格並行檢查）。編輯核心使用純原生 TextKit 2（使用者確認）。流程圖因 Mermaid 只有 JavaScript 實作，以不顯示的 WKWebView 繪製（使用者已知悉）。專案檔以 XcodeGen 的 `project.yml` 產生（委由實作決定，沿用 OKM Mimir、OKM Skirr 的做法）。

## Users

公司內的非技術同事（行政、業務、企劃等）。平常用 Pages 或 Word 寫文件，完全不懂 Markdown 語法，但需要產出 `.md` 檔案供系統或 AI 工具使用，也需要把文件轉成 PDF 交付。

## Product Purpose

OKM Mead 的 macOS 原生重寫版：一個所見即所得的 Markdown 文件編輯器。使用者像在 Pages 裡一樣寫文件、選樣式、插入表格與流程圖，檔案存下來就是標準 Markdown。成功的定義是：使用者從頭到尾不需要看到或輸入任何 Markdown 符號，就能完成一份文件並轉成 PDF。

## Positioning

Typora 這類編輯器假設使用者已經會 Markdown 語法；OKM Mead 把語法完全藏在檔案格式裡，操作方式是文書處理器，產物是 Markdown。相較於 Word，介面只保留文件寫作真正用得到的功能。

## Operating Context

- 取代現有 Electron 版 OKM Mead（MarkText fork，repo `okm-mead`）；未來沿用同一品牌與 bundle id `com.okmaster.OKMMead`。
- 文件以繁體中文為主，夾雜英文與數字。
- 檔案是 `.md` 純文字檔，會被其他系統、AI 工具或懂 Markdown 的同事開啟，因此輸出必須是乾淨、標準的 Markdown（CommonMark + GFM 表格 + Mermaid 程式碼區塊）。

## Capabilities and Constraints

第一版確認的功能：

- 選定文字的段落樣式：標題（多層）、內文等。
- 插入並編輯表格。
- 插入並編輯流程圖，檔案內以 Mermaid 格式儲存。
- 插入 URL 連結。
- 轉換成 PDF。
- 插入圖片（2026-11-12 使用者指定加入）：圖檔在文件存檔後複製到文件旁邊的 `md.img` 資料夾。

限制：

- 僅 macOS。
- 使用者不需要、也不應該被要求輸入 Markdown 或 Mermaid 語法。
- 介面語言：繁體中文（台灣用語）。是否同時提供英文介面尚未決定。

尚未決定：最低支援的 macOS 版本（目前暫定 macOS 15）。

## Brand Commitments

- 名稱依 `okm-mead/docs/BRANDING.md`：顯示用 `OKM Mead`，技術名稱 `OKM-Mead`／`okm-mead`，無符號識別字 `OKMMead`，bundle id `com.okmaster.OKMMead`。
- 色彩一律來自 OKM 共用色票（`okm-brand/tokens.json`，OKMaster 色彩計畫），不在程式中另寫色碼。
- 例外（使用者於 2026-11-11 指定）：深色外觀的三層底色不用色票的海軍藍底，改為視窗黑底加 Liquid Glass 材質、紙張深灰、側欄海軍藍加 Liquid Glass 材質。數值集中在 `Sources/Brand/Theme.swift`。淺色外觀仍照色票。
- 標誌與 App 圖示素材在 `okm-mead/packages/desktop/build/brand/`。
- 使用者指定的參照：操作要像 Apple Pages 一樣流暢；不要 Office Word 的笨重感與複雜介面。

## Evidence on Hand

- 品牌標誌 SVG：`okm-mead/packages/desktop/build/brand/`（mark、lockup、app-icon、document-icon）。
- 共用色票與對比檢查：`okm-brand/`。
- 同系列原生 App 的做法可參考：OKM Mimir（`okm-mimir`）、OKM Skirr。
- 沒有使用者訪談紀錄、使用數據或範例文件；介面示範內容需自行撰寫並標示為示範。

## Product Principles

1. 語法是檔案格式，不是介面。任何功能都不能要求使用者認得 Markdown 或 Mermaid 符號。唯一的例外是使用者主動開啟的「Markdown 原始格式」檢視（2026-11-11 使用者指定加入），給懂語法的人檢查或微調用，預設關閉。
2. 文件優先。畫面上最重要的是使用者正在寫的那一頁，工具退到需要時才出現。
3. 只做 Markdown 能忠實保存的事。不能存進 `.md` 的格式（字型、顏色、任意排版）就不提供，避免「存檔後不見了」。
4. 沿用 Mac 使用者已經會的操作：選單列、快速鍵、工具列、復原、自動儲存都照系統慣例。
5. 輸出要乾淨。存出的 Markdown 給人讀、給機器讀都要像手寫的一樣整齊。

## Accessibility & Inclusion

支援淺色與深色外觀、鍵盤完整操作（所有樣式與插入功能都有選單項目與快速鍵）、VoiceOver 可讀的控制項標籤。色彩對比依 OKM 色票既有檢查（文字 ≥ 4.5:1，控制項邊框與焦點環 ≥ 3:1）。
