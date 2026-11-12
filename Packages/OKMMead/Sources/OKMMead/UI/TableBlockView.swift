// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import SwiftUI

/// 文件裡的表格。直接點儲存格輸入；滑鼠移上來才出現加欄、加列的把手。
struct TableBlockView: View {
    @ObservedObject var model: TableModel
    let attachment: TableAttachment
    weak var editor: EditorController?

    private struct Cell: Hashable {
        var row: Int
        var column: Int
    }

    /// 正在輸入的儲存格，以及要求把焦點移過去的儲存格。
    @State private var focus: Cell?
    @State private var focusRequest: Cell?
    @State private var isHovered = false

    private static let handleSize: CGFloat = 16

    private var showsHandles: Bool { isHovered || focus != nil }

    private var isEditable: Bool { editor?.isEditable ?? false }

    var body: some View {
        if isEditable { editableBody } else { readOnlyBody }
    }

    /// 預覽用：儲存格是排版好的文字（粗體、行內程式碼、連結），沒有加欄、加列的把手。
    private var readOnlyBody: some View {
        grid
            // 儲存格會撐滿可用高度；沒有這一行，文字排版量到的高度是無限大，表格之後的內容都排不出來。
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "表格，\(model.rowCount) 列 \(model.columnCount) 欄", bundle: .module))
    }

    private var editableBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 4) {
                grid
                handle(systemImage: "plus", help: String(localized: "新增一欄", bundle: .module)) { model.insertColumn(at: model.columnCount) }
                    .frame(width: Self.handleSize)
                    .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            handle(systemImage: "plus", help: String(localized: "新增一列", bundle: .module)) { model.insertRow(at: model.rowCount) }
                .frame(height: Self.handleSize)
                .padding(.trailing, Self.handleSize + 4)
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .onHover { isHovered = $0 }
        // 區塊的高度由文字排版決定；內容換行或增減列之後要請它重新量一次。
        .onChange(of: model.rows) {
            DispatchQueue.main.async { editor?.relayoutBlock(attachment) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "表格，\(model.rowCount) 列 \(model.columnCount) 欄", bundle: .module))
    }

    private var grid: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<model.rowCount, id: \.self) { row in
                GridRow {
                    ForEach(0..<model.columnCount, id: \.self) { column in
                        cell(row: row, column: column)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.okmBorderStrong.opacity(0.7), lineWidth: 1)
        }
        .overlay {
            if let editor { BlockSelectionRing(editor: editor, id: ObjectIdentifier(attachment)) }
        }
    }

    private func cell(row: Int, column: Int) -> some View {
        let isHeader = row == 0
        let text = Binding(
            get: { model.rows.indices.contains(row) && model.rows[row].indices.contains(column) ? model.rows[row][column] : "" },
            set: { model.setCell(row: row, column: column, to: $0) }
        )
        return Group {
            if isEditable {
                let position = Cell(row: row, column: column)
                TableCellEditor(
                    markdown: text.wrappedValue,
                    isHeader: isHeader,
                    placeholder: isHeader ? String(localized: "欄位名稱", bundle: .module) : nil,
                    accessibilityLabel: isHeader
                        ? String(localized: "第 \(column + 1) 欄的欄位名稱", bundle: .module)
                        : String(localized: "第 \(row) 列第 \(column + 1) 欄", bundle: .module),
                    wantsFocus: focusRequest == position,
                    editor: editor,
                    onChange: { text.wrappedValue = $0 },
                    onFocusChange: { focused in
                        if focused {
                            focus = position
                            if focusRequest == position { focusRequest = nil }
                        } else if focus == position {
                            focus = nil
                        }
                    },
                    onSubmit: { moveDown(from: row, column: column) },
                    menuItems: { cellMenu(row: row, column: column) }
                )
            } else {
                Text(Self.formatted(text.wrappedValue))
                    .textSelection(.enabled)
            }
        }
            .font(.system(size: 14, weight: isHeader ? .semibold : .regular).monospacedDigit())
            .foregroundStyle(Color.okmText)
            .lineSpacing(3)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(isHeader ? Color.okmTint : Color.okmSurface)
            .overlay(alignment: .trailing) {
                if column < model.columnCount - 1 { Color.okmBorder.frame(width: 1) }
            }
            .overlay(alignment: .bottom) {
                if row < model.rowCount - 1 { Color.okmBorder.frame(height: 1) }
            }
            .accessibilityLabel(isHeader ? String(localized: "第 \(column + 1) 欄的欄位名稱", bundle: .module) : String(localized: "第 \(row) 列第 \(column + 1) 欄", bundle: .module))
    }

    /// 儲存格裡的行內 Markdown（粗體、行內程式碼、連結）排版後的文字；解析不了就原樣顯示。
    private static func formatted(_ cell: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: cell, options: options)) ?? AttributedString(cell)
    }

    /// 在最後一列按 Return 會自動多一列，連續輸入資料時不用伸手拿滑鼠。
    private func moveDown(from row: Int, column: Int) {
        if row == model.rowCount - 1 { model.insertRow(at: model.rowCount) }
        focusRequest = Cell(row: row + 1, column: column)
    }

    private func cellMenu(row: Int, column: Int) -> [TableCellMenuItem] {
        [
            TableCellMenuItem(title: String(localized: "在上方插入一列", bundle: .module), isEnabled: row > 0) { model.insertRow(at: row) },
            TableCellMenuItem(title: String(localized: "在下方插入一列", bundle: .module)) { model.insertRow(at: row + 1) },
            TableCellMenuItem(title: String(localized: "在左側插入一欄", bundle: .module)) { model.insertColumn(at: column) },
            TableCellMenuItem(title: String(localized: "在右側插入一欄", bundle: .module)) { model.insertColumn(at: column + 1) },
            .separator,
            TableCellMenuItem(title: String(localized: "刪除這一列", bundle: .module), isEnabled: row > 0 && model.rowCount > 2) {
                model.removeRow(at: row)
            },
            TableCellMenuItem(title: String(localized: "刪除這一欄", bundle: .module), isEnabled: model.columnCount > 1) {
                model.removeColumn(at: column)
            },
            .separator,
            TableCellMenuItem(title: String(localized: "刪除表格", bundle: .module)) { editor?.deleteBlock(attachment) },
        ]
    }

    private func handle(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.okmTextMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.okmSurfaceSunken, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .opacity(showsHandles ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: showsHandles)
    }
}

/// 區塊被選取（例如按 Delete 準備刪除）時的外框。
struct BlockSelectionRing: View {
    @ObservedObject var editor: EditorController
    let id: ObjectIdentifier

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .strokeBorder(Color(nsColor: Palette.focusRing), lineWidth: 2)
            .padding(-3)
            .opacity(editor.selectedAttachment == id ? 1 : 0)
            .allowsHitTesting(false)
    }
}
