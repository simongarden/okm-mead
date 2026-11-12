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

    @FocusState private var focus: Cell?
    @State private var isHovered = false

    private static let handleSize: CGFloat = 16

    private var showsHandles: Bool { isHovered || focus != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 4) {
                grid
                handle(systemImage: "plus", help: "新增一欄") { model.insertColumn(at: model.columnCount) }
                    .frame(width: Self.handleSize)
                    .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            handle(systemImage: "plus", help: "新增一列") { model.insertRow(at: model.rowCount) }
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
        .accessibilityLabel("表格，\(model.rowCount) 列 \(model.columnCount) 欄")
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
        return TextField("", text: text, prompt: isHeader ? Text("欄位名稱") : nil, axis: .vertical)
            .textFieldStyle(.plain)
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
            .focused($focus, equals: Cell(row: row, column: column))
            .onSubmit { moveDown(from: row, column: column) }
            .contextMenu { cellMenu(row: row, column: column) }
            .accessibilityLabel(isHeader ? "第 \(column + 1) 欄的欄位名稱" : "第 \(row) 列第 \(column + 1) 欄")
    }

    /// 在最後一列按 Return 會自動多一列，連續輸入資料時不用伸手拿滑鼠。
    private func moveDown(from row: Int, column: Int) {
        if row == model.rowCount - 1 { model.insertRow(at: model.rowCount) }
        focus = Cell(row: row + 1, column: column)
    }

    @ViewBuilder
    private func cellMenu(row: Int, column: Int) -> some View {
        Button("在上方插入一列") { model.insertRow(at: row) }
            .disabled(row == 0)
        Button("在下方插入一列") { model.insertRow(at: row + 1) }
        Button("在左側插入一欄") { model.insertColumn(at: column) }
        Button("在右側插入一欄") { model.insertColumn(at: column + 1) }
        Divider()
        Button("刪除這一列") { model.removeRow(at: row) }
            .disabled(row == 0 || model.rowCount <= 2)
        Button("刪除這一欄") { model.removeColumn(at: column) }
            .disabled(model.columnCount <= 1)
        Divider()
        Button("刪除表格", role: .destructive) { editor?.deleteBlock(attachment) }
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
            .strokeBorder(Color(nsColor: OKMPalette.focusRing), lineWidth: 2)
            .padding(-3)
            .opacity(editor.selectedAttachment == id ? 1 : 0)
            .allowsHitTesting(false)
    }
}
