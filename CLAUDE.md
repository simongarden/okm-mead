# OKM Mead 原生版：開發須知

產品定位讀 @PRODUCT.md，視覺規範讀 DESIGN.md，命名規範：顯示用 `OKM Mead`（App 檔名也是 `OKM Mead.app`），執行檔與發行檔名 `OKM-Mead`，必須小寫時用 `okm-mead`，模組與識別字 `OKMMead`（環境變數前綴 `OKMMEAD_`）。

## 指令

- 產生專案：`xcodegen generate`（改了 `project.yml` 或新增檔案後都要跑）
- 編譯：`xcodebuild -project OKM-Mead.xcodeproj -scheme OKM-Mead -derivedDataPath build/DerivedData build`
- 測試：同上，把 `build` 換成 `test`。測試以 App 為宿主執行；斷言失敗時 XCTest 產生報告很慢（可能超過十分鐘），看起來像卡住，其實不是無窮迴圈。

- 發行：`scripts/release.sh`（`--dry-run` 不建立 GitHub Release）。版本在 `project.yml` 的 `MARKETING_VERSION`／`CURRENT_PROJECT_VERSION`，每次發行前先遞增 build、提交並推送。

## 架構重點

編輯核心是儲存庫內的獨立套件 `Packages/OKMMead`（模組 `OKMMead`：`Model`、`Editor`、`UI`、`Export`），App 殼層在 `Sources/`（模組 `OKMMeadApp`：`App`、`Brand`、關於／授權視窗、啟動 Logo），只透過套件的公開介面使用核心。OKM 色票與 App 內附的 Mermaid 由 `Sources/App/EditorSetup.swift` 注入（`MeadConfiguration`）；視窗毛玻璃與外觀切換在 `Sources/UI/DocumentView.swift`，經 `MeadDocumentView` 的插槽放進去。以下各點說的是套件裡的程式。

- 文字儲存區只存「語意屬性」（`.meadBlock`、`.meadBold` 等，見 `Packages/OKMMead/Sources/OKMMead/Model/BlockStyle.swift`）。字型、顏色、段落樣式一律由 `Styling.restyle` 推導，不要直接設定。
- 改動文字儲存區一律經過 `EditorController.edit(_:replacement:actionName:_:)`，才會進復原堆疊。
- 文件結尾的空段落沒有字元可掛屬性，它的樣式記在 `EditorController.trailingSemantic`。
- 表格、流程圖、分隔線是 `BlockAttachment`，各自獨佔一個段落。區塊的高度由 TextKit 決定；內容變動後要呼叫 `relayoutBlock`。
- 清單記號、待辦方框、引言線、程式碼底色由 `MeadLayoutFragment` 繪製，不是文字內容。
- 圖片是 `ImageAttachment`，Markdown 記相對路徑 `md.img/檔名`。還沒存檔的文件先記在 `EditorController.pendingImages`，`fileURL` 一設定（存檔、另存）就由 `storeImages` 複製到文件旁邊；不覆寫既有檔案。
- 任何新功能都要能無損存成 Markdown；存不進去的格式不做。新增匯出規則時在 `Tests/MarkdownRoundTripTests.swift` 補往返測試。

## 編輯核心與 OKM Mimir 共用

OKM Mimir（另一個獨立發行的 App）內建這個專案的編輯核心：`Sources/Model`、`Editor`、`UI`、`Export`，不含 App 殼層（`Sources/App`）、更新機制與品牌（`Sources/Brand`）。兩個產品共用同一份核心，以這個儲存庫為準。

- **核心的修改一律在這裡做、在 Mead 裡測試**，再由 Mimir 同步。Mimir 那邊只放轉接層，不改核心行為。
- **目標結構**：把核心切成這個儲存庫內的獨立 Swift 套件，Mead App 也只透過公開介面使用它；核心穩定後打核心 tag（`core-<主>.<次>.<修訂>`，與 App 版號分開），Mimir 釘在 tag。介面有不相容變更才升核心主版號，並在提交說明寫明需要使用端配合的地方。套件化之前，Mimir 用的是取自特定 commit 的拷貝。
- **核心不得依賴 App 殼層**：`Sources/Model`、`Editor`、`UI`、`Export` 不引用 `Sources/App`、`Sources/Brand`、Sparkle，也不寫死產品名稱、商標圖形或 bundle id。配色、字型、介面文字、檔案位置等使用端各自不同的東西，做成可注入的設定，不為特定產品加分支；兩個 App 的功能差異用設定開關控制。
- **目前狀態（2026-11-12）**：核心已切成 `Packages/OKMMead`（上面寫的 `Sources/Model`、`Editor`、`UI`、`Export` 現在在 `Packages/OKMMead/Sources/OKMMead/` 之下），Mead App 改為只經公開介面使用它；OKM Mimir 的 `Packages/OKMMead` 是同一份內容（只差 `Package.swift` 開頭記錄來源的兩行）。這次套件化連同可嵌入、配色注入、多語系、唯讀預覽、H4–H6／front matter／表格行內格式的保存一起進來，尚未打核心 tag；Mimir 仍以拷貝同步，打 tag 後再改為 git 相依。
- **授權**：核心維持 MIT。不得把 OKM Mimir（AGPL）的程式拷貝進來；共用的程式只能在這裡寫。
- **發行順序**：兩邊都需要的核心修正，先發行 Mead 驗證，再由 Mimir 更新。改到核心的公開介面或往返測試（`Tests/MarkdownRoundTripTests.swift`）涵蓋的行為時，在提交說明標明，方便 Mimir 同步時核對。

## 規則

- 介面文字用正體中文（台灣用語），不得出現 Markdown 或 Mermaid 記號。
- 顏色：核心只用 `Palette`／`Theme` 的語意色（值由使用端注入，核心不寫色碼）；App 殼層只用 `OKMPalette` 與 `AppTheme`。`OKMPalette.swift` 是產生檔，不要手改。
- 核心的介面文字一律 `String(localized:bundle: .module)`／`Text(_:bundle:)`，新增或修改後在 `Packages/OKMMead/Sources/OKMMead/Resources/Localizable.xcstrings` 補上英文（OKM Mimir 有英文介面）。
- Swift 6 嚴格並行檢查。TextKit 與列印的回呼沒有並行標註，既有程式以 `@preconcurrency` 或 `nonisolated(unsafe)` 處理，並在該處註明原因；新增時照同樣做法。
- 不要在這個檔案或任何文件裡放帳號、金鑰、密碼。
