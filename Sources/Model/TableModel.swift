import Foundation

/// 表格內容。第一列固定是表頭（GFM 表格的要求）。
@MainActor
final class TableModel: ObservableObject {
    @Published private(set) var rows: [[String]]
    /// 內容或結構改變時呼叫；用來標記文件已修改並登記復原。
    var onChange: ((_ before: [[String]]) -> Void)?

    init(rows: [[String]]) {
        let width = max(rows.map(\.count).max() ?? 1, 1)
        let padded = rows.map { $0 + Array(repeating: "", count: width - $0.count) }
        self.rows = padded.isEmpty ? [Array(repeating: "", count: width)] : padded
    }

    static func blank(rows: Int, columns: Int) -> TableModel {
        TableModel(rows: Array(repeating: Array(repeating: "", count: columns), count: rows))
    }

    var rowCount: Int { rows.count }
    var columnCount: Int { rows.first?.count ?? 0 }

    func setCell(row: Int, column: Int, to value: String) {
        guard rows.indices.contains(row), rows[row].indices.contains(column), rows[row][column] != value else { return }
        mutate { $0[row][column] = value }
    }

    func insertRow(at index: Int) {
        mutate { $0.insert(Array(repeating: "", count: columnCount), at: min(max(index, 1), $0.count)) }
    }

    func insertColumn(at index: Int) {
        mutate { rows in
            for row in rows.indices { rows[row].insert("", at: min(max(index, 0), rows[row].count)) }
        }
    }

    /// 表頭列不能刪，至少保留表頭加一列。
    func removeRow(at index: Int) {
        guard index > 0, rowCount > 2 else { return }
        mutate { $0.remove(at: index) }
    }

    func removeColumn(at index: Int) {
        guard columnCount > 1 else { return }
        mutate { rows in
            for row in rows.indices { rows[row].remove(at: index) }
        }
    }

    func restore(_ snapshot: [[String]]) {
        mutate { $0 = snapshot }
    }

    private func mutate(_ change: (inout [[String]]) -> Void) {
        let before = rows
        change(&rows)
        onChange?(before)
    }

    var markdown: String {
        func line(_ cells: [String]) -> String {
            "| " + cells.map(Self.escape).joined(separator: " | ") + " |"
        }
        var lines = [line(rows[0]), "| " + Array(repeating: "---", count: columnCount).joined(separator: " | ") + " |"]
        lines += rows.dropFirst().map(line)
        return lines.joined(separator: "\n")
    }

    private static func escape(_ cell: String) -> String {
        let flattened = cell.replacingOccurrences(of: "\n", with: "<br>")
        let escaped = flattened.replacingOccurrences(of: "|", with: "\\|")
        return escaped.isEmpty ? " " : escaped
    }
}
