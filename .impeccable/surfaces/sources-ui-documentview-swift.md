---
version: 1
slug: "sources-ui-documentview-swift"
primary_target: "Sources/UI/DocumentView.swift"
related_targets: []
---

# 編輯器視窗

範圍：文件編輯視窗（唯一的主要畫面）。模式：Operate。

對象與工作：不懂 Markdown 的同事寫一份文件、套樣式、插入表格／流程圖／連結、轉成 PDF。限制：僅 macOS、原生控制項、繁體中文介面、色彩只用 OKM 共用色票。

未決：圖片插入；英文介面。

## Direction contract

THESIS：文書處理器的操作、Markdown 的產物。拒絕 Markdown 編輯器慣用的「左原始碼右預覽」與顯示語法符號的寫法；畫面上永遠沒有 `#`、`*`、`|`。

OWN-WORLD：OKM 色票。視窗底為 `bg`（淺灰藍／深海軍藍），中央一張 `surface` 紙張帶柔和陰影；選取與目前大綱項目用 navy 色階，連結用 `accent`，表頭列用 navy-100。系統字體（SF＋苹方），標題靠字重與字級分層。全部使用 macOS 原生工具列、選單、彈出視窗。

STORY：使用者一開視窗就看到一張紙與游標；樣式名稱以中文顯示在段落旁，知道「這段是標題」而不是「這段有兩個井字號」。

FIRST VIEWPORT：頂部統一工具列（樣式選單、粗體／斜體、清單、連結、表格、流程圖，最右「轉成 PDF」）；左側 220pt 大綱側欄列出標題；右側工作區置中一張 760pt 寬的紙，內文欄寬約 41 個中文字。

簽名手法：邊界樣式標籤。游標所在段落的紙張左邊界顯示該段樣式名稱（如「標題」），可點開換樣式；游標移到別段時標籤以 ease-out 滑過去。

FORM：依版面結構候選清單抽出第 4、6、7 項三種給使用者選，使用者選定第 4 項「大綱側欄＋頂部工具列」。seed:c0c4e7b8f80c2ef5

FINISH：unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
