// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit

/// 唯讀的 Markdown 預覽：和編輯器同一套排版（表格、流程圖、圖片、待辦方框），不能輸入。
/// 鍵盤事件不留在預覽裡，交給外層處理（例如空白鍵關閉預覽、方向鍵換檔）。
@MainActor
public final class MeadPreviewView: NSView {
    private let editor: EditorController

    /// - Parameter fileURL: 文件的位置；文件裡以相對路徑引用的圖片依它所在的資料夾尋找。
    public init(markdown: String, fileURL: URL?) {
        editor = EditorController(markdown: markdown, fileURL: fileURL, isEditable: false)
        super.init(frame: .zero)
        wantsLayer = true
        let scrollView = editor.scrollView
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.page
        addSubview(scrollView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("MeadPreviewView 不支援封存")
    }

    /// 捲到第 `index` 個（0 起算）層級在 `levels` 內的標題。
    public func scrollToHeading(at index: Int, levels: ClosedRange<Int>) {
        let headings = editor.outline.filter { levels.contains($0.level) }
        guard headings.indices.contains(index) else { return }
        editor.scroll(to: headings[index])
    }

    /// 文件排版後的文字（不含 Markdown 記號），給自動化檢查確認內容用。
    public var plainText: String { editor.textView.string }

    /// 文件裡的標題數量，給自動化檢查用。
    public var headingCount: Int { editor.outline.count }
}
