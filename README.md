# OKM Mead（原生版）

給不懂 Markdown 的人用的 Markdown 文件編輯器。像在 Pages 裡一樣寫文件、選樣式、插入表格與流程圖，存下來的檔案就是標準 Markdown；畫面上不會出現 `#`、`*`、`|` 這些記號。

這是 OKM Mead（Electron 版）的 macOS 原生重寫，以 Swift 6 與 TextKit 2 撰寫。產品定位見 [PRODUCT.md](PRODUCT.md)。

## 功能

- 段落樣式：大標題、標題、小標題、內文、引言、項目清單、編號清單（工具列、選單列，或點段落左邊的樣式標籤）
- 粗體、斜體、刪除線、連結（⌘K）
- 表格：直接點儲存格輸入，滑鼠移上去出現加欄、加列的把手，右鍵可插入或刪除列與欄；儲存格裡也能用粗體、斜體、刪除線與連結
- 流程圖：用步驟編輯器製作，檔案內存成 Mermaid
- 圖片：插入後，圖檔會複製到文件旁邊的 `md.img` 資料夾（文件存檔後才複製），Markdown 裡記相對路徑
- 左側大綱：列出文件的標題，點一下跳到該段
- 待辦清單（⇧⌘9）、清單縮排（⌘]／⌘[）
- 預覽列印（⇧⌘P，可切換單頁、雙頁、多頁，並可在其中列印或存成 PDF）、轉成 PDF（⇧⌘E）與列印（⌘P）
- 深色／淺色模式切換（工具列按鈕，或「顯示方式 › 外觀」）
- Markdown 原始格式檢視（⌥⌘/），給懂語法的人檢查用
- 從其他地方貼上帶 Markdown 記號的文字時，自動轉成對應樣式

## 建置

需要 Xcode 16 以上與 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
xcodegen generate
```

```bash
xcodebuild -project OKM-Mead.xcodeproj -scheme OKM-Mead -derivedDataPath build/DerivedData build
```

```bash
xcodebuild -project OKM-Mead.xcodeproj -scheme OKM-Mead -derivedDataPath build/DerivedData test
```

`OKM-Mead.xcodeproj` 由 `project.yml` 產生，不提交到 git。

## 發行

```bash
scripts/release.sh --notes-file <發行說明檔>
```

腳本會跑測試、建置 universal 版、以 Developer ID 簽署、公證並 staple，再用 Sparkle 簽署 dmg 與 `appcast.xml`，最後建立 GitHub Release。`--dry-run` 會完成含公證在內的全部步驟，但只寫到 `build/release/`，不建立 Release。

發行前先遞增 `project.yml` 的 `CURRENT_PROJECT_VERSION`，提交並推送。機器相關的設定放在不入 git 的 `scripts/release.local`，格式見 `scripts/release.local.example`。

## 程式結構

| 路徑 | 內容 |
| --- | --- |
| `Sources/App` | App 進入點、選單列指令、文件讀寫 |
| `Sources/Model` | 段落樣式、Markdown 匯入與匯出、表格與流程圖的資料 |
| `Sources/Editor` | TextKit 2 文字檢視、編輯指令、樣式推導、清單記號繪製、區塊附件 |
| `Sources/UI` | 視窗版面、表格、流程圖編輯器、連結視窗 |
| `Sources/Export` | Mermaid 繪圖與 PDF 輸出（皆透過不顯示的 WKWebView） |
| `Sources/Brand` | OKM 色票（由 `okm-brand/generate.py` 產生）與排版常數 |
| `Resources` | Mermaid、PDF 樣式、色彩資源 |
| `Tests` | Markdown 往返、流程圖解析、編輯行為、PDF 輸出的測試 |

## 目前的限制

- 圖片只能獨立成段；夾在文字中間的圖片會顯示成「〔圖片：說明〕」，存檔時原樣保留。還不能調整圖片大小或修改說明文字。
- 標題只有三層；檔案裡第四層以下的標題會併入小標題。
- `Sources/Brand/OKMPalette.swift` 目前是從 OKM Mimir 複製的產生檔；要讓色票自動同步，需在 `okm-brand/targets.json` 加入這個專案。

## 授權

程式碼採 [MIT 授權](LICENSE)。產品名稱「OKM Mead」、標誌、App 圖示與動態 Logo 不在授權範圍內，見 [TRADEMARKS.md](TRADEMARKS.md)。

內附的第三方元件：swift-markdown（Apache-2.0）、swift-cmark（BSD-2-Clause）、Mermaid（MIT）、Sparkle（MIT）、Poppins 字型（SIL OFL 1.1）。授權全文在 `Resources/LICENSE-*.txt`，App 內可從「關於 OKM Mead › 授權與原始碼」查看。
