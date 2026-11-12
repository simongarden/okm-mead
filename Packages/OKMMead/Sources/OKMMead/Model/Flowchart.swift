// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import Foundation

/// 步驟編輯器能處理的流程圖子集：有方向的步驟與連線。
/// 讀不懂的 Mermaid 內容（其他圖表類型、子圖、樣式指令）回傳 nil，改用文字編輯，不會被改寫。
struct Flowchart: Equatable, Sendable {
    enum Direction: String, CaseIterable, Sendable {
        case down = "TD"
        case right = "LR"

        var displayName: String { self == .down ? String(localized: "由上到下", bundle: .module) : String(localized: "由左到右", bundle: .module) }
    }

    enum Shape: String, CaseIterable, Sendable {
        case terminal, step, decision

        var displayName: String {
            switch self {
            case .terminal: String(localized: "開始／結束", bundle: .module)
            case .step: String(localized: "步驟", bundle: .module)
            case .decision: String(localized: "判斷", bundle: .module)
            }
        }

        var symbolName: String {
            switch self {
            case .terminal: "capsule"
            case .step: "rectangle"
            case .decision: "diamond"
            }
        }

        fileprivate var brackets: (open: String, close: String) {
            switch self {
            case .terminal: ("([", "])")
            case .step: ("[", "]")
            case .decision: ("{", "}")
            }
        }
    }

    struct Node: Identifiable, Equatable, Sendable {
        var id: String
        var text: String
        var shape: Shape
    }

    struct Edge: Identifiable, Equatable, Sendable {
        var id = UUID()
        var from: String
        var to: String
        var label: String = ""

        static func == (lhs: Edge, rhs: Edge) -> Bool {
            lhs.from == rhs.from && lhs.to == rhs.to && lhs.label == rhs.label
        }
    }

    var direction: Direction = .down
    var nodes: [Node] = []
    var edges: [Edge] = []

    static let starter = Flowchart(
        nodes: [
            Node(id: "n1", text: String(localized: "開始", bundle: .module), shape: .terminal),
            Node(id: "n2", text: String(localized: "第一個步驟", bundle: .module), shape: .step),
            Node(id: "n3", text: String(localized: "結束", bundle: .module), shape: .terminal),
        ],
        edges: [Edge(from: "n1", to: "n2"), Edge(from: "n2", to: "n3")]
    )

    // MARK: 編輯

    /// 新步驟接在最後一個步驟後面，省去使用者手動連線。
    mutating func appendNode() {
        let id = nextID()
        let previous = nodes.last?.id
        nodes.append(Node(id: id, text: "", shape: .step))
        if let previous { edges.append(Edge(from: previous, to: id)) }
    }

    mutating func removeNode(_ id: String) {
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
    }

    mutating func addEdge(from id: String) {
        guard let target = nodes.first(where: { $0.id != id })?.id else { return }
        edges.append(Edge(from: id, to: target))
    }

    private func nextID() -> String {
        var index = nodes.count + 1
        while nodes.contains(where: { $0.id == "n\(index)" }) { index += 1 }
        return "n\(index)"
    }

    // MARK: 輸出

    var mermaid: String {
        var lines = ["flowchart \(direction.rawValue)"]
        for node in nodes {
            let brackets = node.shape.brackets
            lines.append("    \(node.id)\(brackets.open)\"\(Self.escape(node.text))\"\(brackets.close)")
        }
        for edge in edges {
            let label = edge.label.trimmingCharacters(in: .whitespaces)
            let arrow = label.isEmpty ? "-->" : "-->|\"\(Self.escape(label))\"|"
            lines.append("    \(edge.from) \(arrow) \(edge.to)")
        }
        return lines.joined(separator: "\n")
    }

    /// Mermaid 的標籤不能直接放雙引號；空白標籤會讓解析失敗，改放一個空格。
    private static func escape(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "\"", with: "#quot;").replacingOccurrences(of: "\n", with: " ")
        return cleaned.isEmpty ? " " : cleaned
    }

    // MARK: 解析

    init(direction: Direction = .down, nodes: [Node] = [], edges: [Edge] = []) {
        self.direction = direction
        self.nodes = nodes
        self.edges = edges
    }

    init?(mermaid source: String) {
        var lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
        guard !lines.isEmpty else { return nil }

        let header = lines.removeFirst().split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let keyword = header.first, keyword == "flowchart" || keyword == "graph", header.count <= 2 else { return nil }
        switch header.count == 2 ? header[1] : "TD" {
        case "TD", "TB": direction = .down
        case "LR": direction = .right
        default: return nil
        }

        for line in lines {
            var scanner = StatementScanner(line.hasSuffix(";") ? String(line.dropLast()) : line)
            guard var current = scanner.node() else { return nil }
            register(current)
            while !scanner.isAtEnd {
                guard let label = scanner.arrow(), let next = scanner.node() else { return nil }
                register(next)
                edges.append(Edge(from: current.id, to: next.id, label: label))
                current = next
            }
        }
        guard !nodes.isEmpty else { return nil }
    }

    /// 同一個步驟可能先出現在連線裡、之後才定義文字；有文字的定義優先。
    private mutating func register(_ parsed: StatementScanner.ParsedNode) {
        if let index = nodes.firstIndex(where: { $0.id == parsed.id }) {
            if let text = parsed.text, let shape = parsed.shape {
                nodes[index].text = text
                nodes[index].shape = shape
            }
        } else {
            nodes.append(Node(id: parsed.id, text: parsed.text ?? parsed.id, shape: parsed.shape ?? .step))
        }
    }
}

private struct StatementScanner {
    struct ParsedNode {
        var id: String
        var text: String?
        var shape: Flowchart.Shape?
    }

    private let characters: [Character]
    private var position = 0

    init(_ line: String) {
        characters = Array(line)
    }

    var isAtEnd: Bool {
        var index = position
        while index < characters.count, characters[index] == " " { index += 1 }
        return index >= characters.count
    }

    private mutating func skipSpaces() {
        while position < characters.count, characters[position] == " " { position += 1 }
    }

    private mutating func consume(_ literal: String) -> Bool {
        let expected = Array(literal)
        guard position + expected.count <= characters.count,
              Array(characters[position..<position + expected.count]) == expected else { return false }
        position += expected.count
        return true
    }

    private mutating func text(until closing: String) -> String? {
        let terminator = Array(closing)
        var index = position
        while index + terminator.count <= characters.count {
            if Array(characters[index..<index + terminator.count]) == terminator {
                let raw = String(characters[position..<index]).trimmingCharacters(in: .whitespaces)
                position = index + terminator.count
                return Self.unquote(raw)
            }
            index += 1
        }
        return nil
    }

    private static func unquote(_ raw: String) -> String {
        var value = raw
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        return value.replacingOccurrences(of: "#quot;", with: "\"").trimmingCharacters(in: .whitespaces)
    }

    mutating func node() -> ParsedNode? {
        skipSpaces()
        let start = position
        while position < characters.count,
              characters[position].isLetter || characters[position].isNumber || characters[position] == "_" {
            position += 1
        }
        guard position > start else { return nil }
        let id = String(characters[start..<position])
        let reserved: Set<String> = ["subgraph", "end", "style", "classDef", "class", "click", "linkStyle", "direction"]
        guard !reserved.contains(id) else { return nil }

        let shapes: [(open: String, close: String, shape: Flowchart.Shape)] = [
            ("([", "])", .terminal), ("{", "}", .decision), ("[", "]", .step), ("(", ")", .terminal),
        ]
        for candidate in shapes where consume(candidate.open) {
            // `((`、`[[`、`{{`、`[(` 等是步驟編輯器沒有的形狀。
            if position < characters.count, "([{/\\".contains(characters[position]) { return nil }
            guard let text = text(until: candidate.close) else { return nil }
            return ParsedNode(id: id, text: text, shape: candidate.shape)
        }
        return ParsedNode(id: id)
    }

    /// 只接受實線箭頭：`-->`、`-->|標示|`、`-- 標示 -->`。回傳連線上的標示文字。
    mutating func arrow() -> String? {
        skipSpaces()
        if consume("-->") {
            skipSpaces()
            guard consume("|") else { return "" }
            return text(until: "|")
        }
        if consume("--") {
            guard position < characters.count, characters[position] != "-" else { return nil }
            return text(until: "-->")
        }
        return nil
    }
}
