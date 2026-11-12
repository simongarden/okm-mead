---
name: OKM Mead
description: 像文書處理器一樣操作、存下來是標準 Markdown 的 macOS 原生文件編輯器
colors:
  # 語意色（淺色外觀）。來源：Sources/Brand/OKMPalette.swift（由 okm-brand/tokens.json 產生）
  bg: "#F6F8FB"
  surface: "#FFFFFF"
  surface-sunken: "#EDF0F5"
  border: "#D7DDE8"
  border-strong: "#8391AE"
  text: "#0A1630"
  text-muted: "#4E5C7A"
  primary: "#0B2C67"
  primary-hover: "#1A3F82"
  on-primary: "#FFFFFF"
  accent: "#2F6AAD"
  focus-ring: "#0F6FA3"
  success: "#1E7F7F"
  warning: "#B45309"
  danger: "#C0362C"
  # 語意色（深色外觀）
  bg-dark: "#000000"
  surface-dark: "#2A2A2D"
  surface-sunken-dark: "#36363A"
  border-dark: "#24345A"
  border-strong-dark: "#6A7DA3"
  text-dark: "#E6EBF3"
  text-muted-dark: "#A9B6CF"
  primary-dark: "#9FB3D9"
  primary-hover-dark: "#B9C9E6"
  on-primary-dark: "#0A1630"
  accent-dark: "#6FA3E6"
  focus-ring-dark: "#56B8E6"
  success-dark: "#4EC0BA"
  warning-dark: "#F0A04B"
  danger-dark: "#F07A6E"
  # 本 App 實際取用的色階（固定色）
  navy-950: "#050F26"
  navy-700: "#1A3F82"
  navy-600: "#2C559C"
  navy-200: "#B9C9E6"
  navy-100: "#E3EAF6"
typography:
  # 尺寸單位為 macOS 的 pt（1pt = 1 CSS px）。來源：Sources/Brand/Theme.swift
  title:
    fontFamily: "-apple-system, 'SF Pro Text', 'PingFang TC', sans-serif"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.2
  heading:
    fontFamily: "-apple-system, 'SF Pro Text', 'PingFang TC', sans-serif"
    fontSize: "21px"
    fontWeight: 600
    lineHeight: 1.2
  subheading:
    fontFamily: "-apple-system, 'SF Pro Text', 'PingFang TC', sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.2
  body:
    fontFamily: "-apple-system, 'SF Pro Text', 'PingFang TC', sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
  code:
    fontFamily: "'SF Mono', Menlo, monospace"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.3
  table-cell:
    fontFamily: "-apple-system, 'SF Pro Text', 'PingFang TC', sans-serif"
    fontSize: "14px"
    fontWeight: 400
    fontFeature: "tnum"
  margin-tag:
    fontFamily: "-apple-system, 'SF Pro Text', 'PingFang TC', sans-serif"
    fontSize: "11px"
    fontWeight: 500
rounded:
  tag: "4px"
  block: "6px"
spacing:
  code-inset: "14px"
  group-trailing: "12px"
  list-indent: "24px"
  canvas-margin: "28px"
  page-padding-min: "36px"
  page-top: "64px"
  page-padding: "72px"
  page-bottom: "96px"
components:
  page:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.block}"
    width: "760px"
    padding: "64px 72px 96px"
  button-export:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
  margin-style-tag:
    textColor: "{colors.text-muted}"
    typography: "{typography.margin-tag}"
    rounded: "{rounded.tag}"
    height: "18px"
  margin-style-tag-hover:
    backgroundColor: "{colors.navy-100}"
    textColor: "{colors.primary}"
  outline-row:
    textColor: "{colors.text}"
    rounded: "{rounded.block}"
  outline-row-current:
    backgroundColor: "{colors.navy-100}"
    textColor: "{colors.primary}"
    rounded: "{rounded.block}"
  table-header-cell:
    backgroundColor: "{colors.navy-100}"
    textColor: "{colors.text}"
    typography: "{typography.table-cell}"
    padding: "8px 10px"
  table-cell:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    typography: "{typography.table-cell}"
    padding: "8px 10px"
  code-block:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.text}"
    typography: "{typography.code}"
    rounded: "{rounded.block}"
    padding: "0 14px"
  checkbox-checked:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    size: "14px"
---

# Design System: OKM Mead

> 本文件由已完成的原生版程式碼與實際視窗截圖整理而成（`Sources/Brand/`、`Sources/Editor/`、`Sources/UI/`、`Resources/export.css`、`.impeccable/review/`）。數值以程式碼為準；色彩以 `Sources/Brand/OKMPalette.swift` 為唯一來源。

## Overview

**Creative North Star: "桌上的一張紙"**（暫定名稱，取自方向文件的 STORY，尚未經使用者確認）

（深色外觀例外，使用者於 2026-11-11 指定：視窗為黑底加 Liquid Glass 工具列，紙張為深灰 `#2A2A2D`，側欄為海軍藍加 Liquid Glass 材質；這三層不取自色票，數值在 `Sources/Brand/Theme.swift` 的 `canvas`、`page`、`pageSunken`、`sidebarTint`。以下描述的是淺色外觀。）

打開視窗看到的是一張置中的紙和一個游標。視窗底是帶一點藍的淺灰（`bg`），紙是 `surface`，四周一圈柔和的陰影把紙從桌面托起來；除此之外畫面上沒有其他有重量的東西。左邊的大綱側欄沉在 `surface-sunken` 裡，頂部是 macOS 原生的統一工具列。整個介面的品牌感只來自 OKM 共用色票的海軍藍色階，不靠插圖、漸層或自製控制項。

密度偏鬆：內文 15pt、行高 1.45、欄寬 616pt（約 41 個中文字）。標題不換顏色，只靠字級與字重分層。Markdown 的語法符號從不出現在畫面上：清單記號、待辦方框、引言細線、程式碼底色都是畫在文字之外的裝飾，選不到、也複製不到。

這個視覺世界是 OKM 系列 App 共用的，本 App 是新套用的一員；因此所有顏色都必須能在色票裡找到名字。

**Key Characteristics:**
- 一張 760pt 寬的紙置中，是畫面上唯一有陰影的元素。
- 色彩全部取自 OKM 色票的語意色；海軍藍淺底只標示「目前所在」與表頭。
- 系統字體（SF＋苹方），標題靠字重與字級分層，不靠顏色。
- 控制項一律是 macOS 原生元件；區塊上的操作把手平常隱藏，需要時才浮現。
- 淺色與深色外觀各有一組對應值，由同一個語意名稱切換。
- 簽名手法：紙張左邊界的樣式標籤，跟著游標滑到目前段落旁。

## Colors

冷調的海軍藍與灰藍：底色與邊框來自 slate 色階，強調與選取來自 navy 色階，全畫面只有連結使用較亮的藍。

### Primary
- **品牌海軍藍 `primary`**：主要動作與「已確定」的狀態。工具列的「轉成 PDF」按鈕底色、游標（插入點）顏色、已勾選的待辦方框、目前大綱項目的文字、樣式標籤 hover 時的文字。深色外觀下反轉為淺藍（`primary-dark`），其上的文字用 `on-primary`。
- **品牌淺底 `navy-100`／深色 `navy-700`**（程式中的 `Theme.tint`）：目前大綱項目的底、表格表頭列的底、樣式標籤 hover 的底，以及流程圖節點的填色。
- **選取底色 `navy-200`／深色 `navy-600`**（程式中的 `Theme.selection`）：文字選取範圍。

### Secondary
- **連結藍 `accent`**：文件裡的連結文字，底線為同色 45% 透明度。同一組值也放在 `Resources/Assets.xcassets/AccentColor.colorset`，所以系統控制項的預設強調色（分段選擇器、預設按鈕、連結式按鈕）也是它。

### Tertiary
- **焦點水藍 `focus-ring`**：只用在區塊（表格、流程圖）被選取時的 2pt 外框。
- **提醒橘 `warning`**：只用在流程圖無法顯示時的警告圖示，並且一定搭配文字說明。

### Neutral
- **頁面底 `bg`**：視窗底色、捲動區底色、流程圖編輯器的預覽區。
- **紙面 `surface`**：紙張、表格的一般儲存格、流程圖編輯器的步驟面板。
- **凹陷面 `surface-sunken`**：大綱側欄、程式碼區塊、行內程式碼的底、表格的加欄／加列把手、流程圖 hover 時的淡底（60% 透明度）。
- **細邊 `border`**：表格內部格線、分隔線（1pt）。
- **強邊 `border-strong`**：表格外框（70% 透明度）、未勾選的待辦方框（1.5pt）、引言左側的細線（1pt）、流程圖節點外框。
- **主要文字 `text`**：內文與所有標題。
- **次要文字 `text-muted`**：引言內文、清單記號與編號、樣式標籤、側欄第三層標題、表單欄位名稱、流程圖連線。

色票中還有 `primary-hover`、`success`、`danger` 三個語意色，這一版的介面尚未取用（刪除動作交給系統的 destructive 樣式）；需要時直接用這些名稱，不另外調色。

### Named Rules
**色票唯一來源規則。** Swift 程式裡不寫色碼，顏色一律以 `OKMPalette` 的名稱取用；深淺外觀由語意色自己切換，不在畫面層判斷。唯一的例外是 `Resources/export.css`（PDF 沒有深色外觀），它重複了一份淺色值，改色票時要一起更新。

**淺底只標示所在規則。** `navy-100` 淺底不拿來裝飾版面；它出現就代表「你在這裡」（目前大綱項目、滑鼠所在的樣式標籤）或「這一列是表頭」。

**連結獨佔亮藍規則。** 紙上唯一比海軍藍更亮的藍是連結。標題、強調、清單記號都不使用 `accent`。

## Typography

**Display Font:** 系統字體（SF Pro，中文為苹方繁體 PingFang TC）
**Body Font:** 同上
**Label/Mono Font:** SF Mono（`monospacedSystemFont`），PDF 的後備字為 Menlo

**Character:** 不引入品牌字體，文件看起來就像 macOS 本身寫出來的。層次完全由字級（28／21／17／15）與字重（700／600／400）拉開，顏色保持一致。

### Hierarchy
- **大標題 `title`**（700，28pt，行高 1.2）：文件標題。段前 4pt、段後 14pt。
- **標題 `heading`**（600，21pt，行高 1.2）：章節。段前 26pt、段後 8pt。
- **小標題 `subheading`**（600，17pt，行高 1.2）：小節。段前 18pt、段後 6pt。
- **內文 `body`**（400，15pt，行高 1.45）：段落、清單、引言。段後為字級的 0.7 倍（10.5pt）；欄寬 616pt，約 41 個中文字。清單項目之間 4pt。
- **程式碼 `code`**（等寬 400，13pt，行高 1.3）：程式碼區塊；行內程式碼比所在段落小 1pt（內文中為 14pt）。
- **表格文字 `table-cell`**（14pt，表頭 600、一般 400，等寬數字，行距加 3pt）。
- **邊界標籤 `margin-tag`**（500，11pt）：紙張邊界的樣式名稱。

PDF 輸出（`Resources/export.css`）是同一套階層換成印刷尺寸：內文 10.5pt／行高 1.7，大標題 21pt／700，標題 15pt／600，小標題 12pt／600，表格 9.5pt，程式碼 9pt。

### Named Rules
**字重分層規則。** 標題與內文同色（`text`），只用字級與字重區分。不為標題另外上色、加底線或加裝飾線。

**中文粗斜規則。** 內文的粗體直接用 bold（700），因為中文字的 semibold 與 regular 差異太小；斜體用 0.2 的斜切變形產生，中英文斜度才一致。

**上寬下窄規則。** 標題上方的留白明顯大於下方（26／8、18／6），讓標題貼著它帶領的內容。連續的清單、引言或程式碼段落之間不另外留段距，整組結束後才留 12pt。

## Layout

三個區域：頂部的原生統一工具列、左側大綱側欄（理想寬度 220pt，可調 180–320pt）、右側工作區。工作區中央是一張固定 760pt 寬的紙，左右內距各 72pt、上 64pt、下 96pt，紙與視窗上下緣相距 20pt。

視窗變窄時紙張跟著縮：紙與工作區左右邊緣至少保留 28pt（`canvas-margin`），左右內距等比例縮小但不低於 36pt。沒有其他斷點；文字欄永遠是單欄。

紙內的縮排以 24pt 為一階：清單每一層 24pt，引言內縮 24pt（細線在距欄左緣 6pt 處）。清單記號畫在文字左側 8pt 處。程式碼區塊的底色滿欄寬，文字左右各內縮 14pt。大綱側欄每一層標題內縮 12pt。

工具列的排列（由左至右）：樣式選單（118pt 寬）、粗體／斜體、項目清單／編號清單、連結／表格／流程圖（圖示加文字）；最右側單獨一顆「轉成 PDF」。

## Elevation & Depth

以色調分層為主：`bg`（桌面）→ `surface`（紙）→ `surface-sunken`（側欄、程式碼）。全畫面只有一道自繪的陰影，就是紙張底下那一圈。彈出視窗與表單的陰影交給系統。

### Shadow Vocabulary
- **紙張陰影**（顏色 `navy-950`，淺色外觀 10%、深色外觀 50% 透明度；向下位移 2pt；模糊 14pt）：只用在文件紙張。

### Named Rules
**唯一陰影規則。** 目前只有紙張有陰影。表格、流程圖、程式碼區塊都平貼在紙上，靠邊框或底色區分，不另外浮起。

## Shapes

小圓角、細線條。文件裡的區塊一律 6pt 圓角：紙張、程式碼區塊、表格外框、目前大綱項目的底、流程圖 hover 的底、文字編輯框。小型元件用 4pt（邊界樣式標籤的 hover 底）。待辦方框是 14pt 見方、3.5pt 圓角。

線條都是 1pt：表格格線、分隔線、引言細線。只有兩處較粗：未勾選的待辦方框 1.5pt、區塊選取外框 2pt。連續的程式碼段落合成一個區塊，只有第一行的上緣與最後一行的下緣有圓角。

PDF 的圓角換成印刷尺寸：程式碼區塊 4pt、行內程式碼 2pt；表格為直角。

## Components

整體性格：能用系統元件就用系統元件；自己畫的只有紙上的東西，而且都安靜。

### Buttons
- **主要動作（轉成 PDF）：** 系統的 `borderedProminent` 樣式，底色指定為 `primary`，文字 `on-primary`。輸出進行中改顯示小型進度指示並停用。整個視窗只有這一顆有填色的按鈕。
- **工具列按鈕：** 系統樣式。粗體、斜體、清單是可切換的圖示按鈕；連結、表格、流程圖是圖示加文字。全部有說明提示，常用的附快速鍵。
- **區塊上的按鈕：** 流程圖右上角的「編輯流程圖」是小尺寸系統按鈕，內縮 8pt，滑鼠移上來或區塊被選取時才出現。
- **表單按鈕：** 取消與完成用系統樣式，完成是預設動作（Return）；移除、刪除用系統的 destructive 角色。

### Cards / Containers
- **紙張：** 760pt 寬、6pt 圓角、`surface` 底、紙張陰影、無邊框。內距 64／72／96pt。空白文件時在游標位置顯示佔位文字（「文件標題」或「開始輸入…」）。
- **程式碼區塊：** `surface-sunken` 底、6pt 圓角、無邊框、文字左右內縮 14pt。行內程式碼只有同色底，無圓角框線。
- **流程圖區塊：** 圖置中，上下各 12pt；最大顯示尺寸 560×460pt，超過就等比例縮小。平常沒有底色，hover 時浮出 60% 的 `surface-sunken` 底（0.15 秒 ease-out）。節點填 `navy-100`（深色 `navy-700`），外框 `border-strong`，連線 `text-muted`。載入中顯示小型進度指示，失敗時顯示警告圖示、一句說明與「打開來修正」按鈕。
- **區塊選取外框：** 2pt 的 `focus-ring`，在區塊外 3pt 處；表格與流程圖共用。

### Inputs / Fields
- **表單欄位：** 系統的 `roundedBorder` 文字欄位。欄位名稱用 `text-muted`，放在欄位左側、以基線對齊。
- **表格儲存格：** 無框的純文字欄位，直接點了就打字；內距左右 10pt、上下 8pt。表頭列底色為品牌淺底、字重 600，空白時提示「欄位名稱」。
- **待辦方框：** 未勾選是 1.5pt 的 `border-strong` 空框；勾選後填 `primary`，勾號為 1.6pt 圓頭線、顏色 `on-primary`。

### Navigation
- **大綱側欄：** 系統的側欄清單，底色 `surface-sunken`，區段標題「大綱」為系統樣式。項目單行顯示、每層內縮 12pt。第一層 600 字重；第三層用 `text-muted`。目前所在的項目：文字 `primary`、600 字重、6pt 圓角的品牌淺底（左右各內縮 8pt）。沒有標題時，側欄中央以 `text-muted` 的說明文字解釋如何讓標題出現在這裡。

### 表格
外框 1pt（`border-strong` 70% 透明度）、6pt 圓角並裁切內容；內部格線 1pt `border`。滑鼠移上來或有儲存格取得焦點時，右側與下方各出現一條 16pt 的把手（`surface-sunken` 底、5pt 圓角、10pt 的加號），用來加欄、加列；0.15 秒 ease-out 淡入淡出。列與欄的插入、刪除在右鍵選單。

### 邊界樣式標籤（簽名元件）
游標所在段落的紙張左邊界，顯示該段的樣式名稱（如「標題」）和一個向下的小箭頭；與文字欄相距 14pt，垂直對齊第一行字身的中心。平常是 11pt、`text-muted` 的安靜文字（箭頭 70% 透明度）；滑鼠移上去時浮出 4pt 圓角的品牌淺底、文字轉為 `primary`，點開是樣式選單。游標移到別的段落時，標籤以 0.24 秒、`cubic-bezier(0.16, 1, 0.3, 1)` 滑過去；系統開啟「減少動態效果」時直接跳到定位。游標在表格或流程圖上時隱藏。

### 彈出視窗與表單
- **連結小視窗：** 340pt 寬、內距 16pt 的系統彈出視窗，兩列欄位（顯示文字、網址），列距 10pt。
- **流程圖編輯器：** 960×620pt 的表單。左側 420pt 是 `surface` 底的步驟面板（內距 20pt，步驟之間用分隔線），右側是 `bg` 底的即時預覽；底部一列放取消與完成。停止輸入 0.28 秒後才更新預覽，避免閃爍。

## Do's and Don'ts

### Do:
- **Do** 以 `OKMPalette` 的語意名稱取用顏色；需要淺底或選取色時用既有的 `Theme.tint`、`Theme.selection`。
- **Do** 讓新的文件區塊沿用 6pt 圓角、1pt 線條，平貼在紙上。
- **Do** 用字級與字重（28／21／17／15，700／600／400）建立層次，標題維持 `text` 色。
- **Do** 把區塊上的操作把手做成「hover、取得焦點或被選取時才出現」，並用 0.15 秒 ease-out 淡入；只用鍵盤的人也要看得到。
- **Do** 優先使用 macOS 原生控制項（工具列、選單、彈出視窗、表單、側欄清單）與 SF Symbols。
- **Do** 兩種外觀都檢查；深色外觀的值由語意色提供，不另外調。
- **Do** 改動色票時同步更新 `Resources/export.css` 的淺色值。
- **Do** 在位移動畫上尊重「減少動態效果」設定。

### Don't:
- **Don't** 在 Swift 程式裡寫色碼，或加入色票以外的顏色。
- **Don't** 讓任何 Markdown 或 Mermaid 符號（`#`、`*`、`|`）出現在介面上；清單記號、方框、引言線都是畫出來的裝飾，不是文字。
- **Don't** 用 `accent` 為標題、強調文字或裝飾上色；紙上的亮藍只屬於連結。
- **Don't** 把品牌淺底當成版面裝飾；它只標示目前所在與表頭。
- **Don't** 在視窗裡放第二顆填色的主要按鈕；「轉成 PDF」是唯一的一顆。
- **Don't** 提供存不進 `.md` 的格式（字型、文字顏色、任意排版）的控制項。
