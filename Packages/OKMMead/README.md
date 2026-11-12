# OKMMead — OKM Mead 的 Markdown 編輯核心

Swift 6＋TextKit 2 的所見即所得 Markdown 編輯器核心，由 OKM Mead 與 OKM Mimir 共用。程式碼採 MIT 授權（見 `LICENSE`）；
「OKM Mead」的名稱、標誌與 App 圖示不在 MIT 授權範圍內，這個套件也不包含它們（見 OKM Mead 儲存庫的 `TRADEMARKS.md`）。

以 OKM Mead 的儲存庫（`simongarden/okm-mead` 的 `Packages/OKMMead`）為準；其他 App 內的拷貝只同步、不各自修改。

## 內容

- `Model`：區塊模型、Markdown 匯入與匯出、表格、流程圖、圖片存放規則。
- `Editor`：`EditorController`、`MeadTextView`、樣式推導、排版片段、區塊附件。
- `UI`：文件視圖、表格／流程圖／圖片區塊、連結編輯、流程圖步驟編輯器、預覽列印、唯讀預覽。
- `Export`：PDF 與列印、Mermaid 繪製。
- `Resources`：`diagram.js`、`export.css`、`Localizable.xcstrings`（介面文字以正體中文為 key，附英文）。

不含 App 殼層（文件類別、選單指令、視窗底層）、更新機制、品牌色票與圖示、Mermaid 腳本。

## 使用端的接點

- `MeadConfiguration.appearance`：語意色（`MeadAppearance`）。套件不帶品牌色，預設是系統色。
- `MeadConfiguration.mermaidScript`：單檔 Mermaid 腳本的位置（需定義全域 `mermaid`）；沒有設定時流程圖無法繪製。
- `EditorController(markdown:fileURL:isEditable:)`：`markdown`、`onMarkdownChange`（內容變動後同一輪事件通知一次）、
  `onImagesStored`、`focus()`，以及樣式、插入、原始格式、PDF 與列印等指令。
- `MeadDocumentView(editor:drawsCanvasBackground:showsMenuOnlyCommands:sidebarBackground:trailingToolbar:)`：
  大綱、紙張與工具列（SwiftUI）。使用端可以換掉畫布與側欄的底層、在工具列右側加項目。
- `MeadPreviewView(markdown:fileURL:)`：唯讀預覽（AppKit），`scrollToHeading(at:levels:)`。

讀寫檔案、文字編碼、自動儲存與視窗由使用端負責；套件只依賴 swift-markdown，沒有任何使用端專屬的邏輯或名稱。
配色、介面語言、功能差異一律經上面的設定點注入，不為特定產品加分支。

## 內容保存

任何功能都要能無損存成 Markdown。編輯器不認得的內容原樣保留：第四到第六層標題顯示成小標題、存檔維持原層級；
檔頭的 YAML front matter、HTML 區塊原樣寫回；表格儲存格保留行內的粗體、行內程式碼與連結。表格的欄位對齊不保留。
