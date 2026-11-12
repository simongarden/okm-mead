# OKM Mead 原生版：開發須知

產品定位讀 @PRODUCT.md，視覺規範讀 DESIGN.md，命名規範：顯示用 `OKM Mead`，bundle 與執行檔 `OKM-Mead`，必須小寫時用 `okm-mead`，模組與識別字 `OKMMead`（環境變數前綴 `OKMMEAD_`）。

## 指令

- 產生專案：`xcodegen generate`（改了 `project.yml` 或新增檔案後都要跑）
- 編譯：`xcodebuild -project OKM-Mead.xcodeproj -scheme OKM-Mead -derivedDataPath build/DerivedData build`
- 測試：同上，把 `build` 換成 `test`。測試以 App 為宿主執行；斷言失敗時 XCTest 產生報告很慢（可能超過十分鐘），看起來像卡住，其實不是無窮迴圈。

- 發行：`scripts/release.sh`（`--dry-run` 不建立 GitHub Release）。版本在 `project.yml` 的 `MARKETING_VERSION`／`CURRENT_PROJECT_VERSION`，每次發行前先遞增 build、提交並推送。

## 架構重點

- 文字儲存區只存「語意屬性」（`.meadBlock`、`.meadBold` 等，見 `Sources/Model/BlockStyle.swift`）。字型、顏色、段落樣式一律由 `Styling.restyle` 推導，不要直接設定。
- 改動文字儲存區一律經過 `EditorController.edit(_:replacement:actionName:_:)`，才會進復原堆疊。
- 文件結尾的空段落沒有字元可掛屬性，它的樣式記在 `EditorController.trailingSemantic`。
- 表格、流程圖、分隔線是 `BlockAttachment`，各自獨佔一個段落。區塊的高度由 TextKit 決定；內容變動後要呼叫 `relayoutBlock`。
- 清單記號、待辦方框、引言線、程式碼底色由 `MeadLayoutFragment` 繪製，不是文字內容。
- 任何新功能都要能無損存成 Markdown；存不進去的格式不做。新增匯出規則時在 `Tests/MarkdownRoundTripTests.swift` 補往返測試。

## 規則

- 介面文字用正體中文（台灣用語），不得出現 Markdown 或 Mermaid 記號。
- 顏色只用 `OKMPalette` 與 `Theme` 的語意色；`OKMPalette.swift` 是產生檔，不要手改。
- Swift 6 嚴格並行檢查。TextKit 與列印的回呼沒有並行標註，既有程式以 `@preconcurrency` 或 `nonisolated(unsafe)` 處理，並在該處註明原因；新增時照同樣做法。
- 不要在這個檔案或任何文件裡放帳號、金鑰、密碼。
