// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import SwiftUI

/// 流程圖的步驟編輯器：左邊列出步驟與連線，右邊即時預覽。使用者不需要看到 Mermaid 文字。
struct FlowchartEditor: View {
    let request: DiagramEditRequest
    let onFinish: (String?) -> Void

    @State private var chart: Flowchart
    /// 檔案裡的圖表用了步驟編輯器不支援的寫法時，改成直接編輯文字，避免存檔時弄壞內容。
    @State private var isTextMode: Bool
    @State private var text: String
    @State private var preview: NSImage?
    @State private var previewFailed = false
    @Environment(\.colorScheme) private var colorScheme

    init(request: DiagramEditRequest, onFinish: @escaping (String?) -> Void) {
        self.request = request
        self.onFinish = onFinish
        let source = request.attachment.model.source
        let parsed = Flowchart(mermaid: source)
        _chart = State(initialValue: parsed ?? .starter)
        _isTextMode = State(initialValue: parsed == nil)
        _text = State(initialValue: source)
    }

    private var source: String { isTextMode ? text : chart.mermaid }

    private struct PreviewKey: Hashable {
        var source: String
        var dark: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Group {
                    if isTextMode { textPanel } else { stepsPanel }
                }
                .frame(width: 420)
                Divider()
                previewPanel
            }
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "取消", bundle: .module), role: .cancel) { onFinish(nil) }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "完成", bundle: .module)) { onFinish(source) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.okmPrimary)
                    .disabled(!isTextMode && chart.nodes.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 960, height: 620)
        .task(id: PreviewKey(source: source, dark: colorScheme == .dark)) {
            // 邊打字邊重畫會閃爍，停手一小段時間再更新預覽。
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            do {
                preview = try await MermaidRenderer.shared.image(for: source, dark: colorScheme == .dark)
                previewFailed = false
            } catch is CancellationError {
            } catch {
                previewFailed = true
            }
        }
    }

    // MARK: 步驟

    private var stepsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("流程圖", bundle: .module)
                    .font(.title3.weight(.semibold))
                    .padding(.bottom, 14)

                Picker(String(localized: "方向", bundle: .module), selection: $chart.direction) {
                    ForEach(Flowchart.Direction.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.bottom, 18)

                ForEach($chart.nodes) { $node in
                    stepRow($node)
                    Divider().padding(.vertical, 12)
                }

                Button {
                    chart.appendNode()
                } label: {
                    Label(String(localized: "新增步驟", bundle: .module), systemImage: "plus")
                }
            }
            .padding(20)
        }
        .background(Color.okmSurface)
    }

    private func stepRow(_ node: Binding<Flowchart.Node>) -> some View {
        let id = node.wrappedValue.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Picker(String(localized: "形狀", bundle: .module), selection: node.shape) {
                        ForEach(Flowchart.Shape.allCases, id: \.self) { shape in
                            Label(shape.displayName, systemImage: shape.symbolName).tag(shape)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: node.wrappedValue.shape.symbolName)
                        .frame(width: 20)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(String(localized: "形狀：\(node.wrappedValue.shape.displayName)", bundle: .module))
                .accessibilityLabel(String(localized: "形狀", bundle: .module))
                .accessibilityValue(node.wrappedValue.shape.displayName)

                TextField(String(localized: "步驟名稱", bundle: .module), text: node.text)
                    .textFieldStyle(.roundedBorder)

                Button {
                    chart.removeNode(id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "刪除這個步驟", bundle: .module))
                .accessibilityLabel(String(localized: "刪除這個步驟", bundle: .module))
                .disabled(chart.nodes.count <= 1)
            }

            ForEach($chart.edges) { $edge in
                if edge.from == id {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.down.right")
                            .foregroundStyle(Color.okmTextMuted)
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        Text("接到", bundle: .module)
                            .foregroundStyle(Color.okmTextMuted)
                        Picker(String(localized: "接到", bundle: .module), selection: $edge.to) {
                            ForEach(chart.nodes.filter { $0.id != id }) { target in
                                Text(target.text.isEmpty ? String(localized: "（未命名步驟）", bundle: .module) : target.text).tag(target.id)
                            }
                        }
                        .labelsHidden()
                        TextField(String(localized: "線上的文字", bundle: .module), text: $edge.label, prompt: Text("例如：是", bundle: .module))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 96)
                        Button {
                            chart.edges.removeAll { $0.id == edge.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help(String(localized: "移除這條連線", bundle: .module))
                        .accessibilityLabel(String(localized: "移除這條連線", bundle: .module))
                    }
                }
            }

            Button(String(localized: "加一條連線", bundle: .module)) { chart.addEdge(from: id) }
                .buttonStyle(.link)
                .padding(.leading, 28)
                .disabled(chart.nodes.count <= 1)
        }
    }

    // MARK: 文字模式

    private var textPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("圖表內容", bundle: .module)
                .font(.title3.weight(.semibold))
            Text("這張圖表用了步驟編輯器不支援的寫法，所以直接顯示它的文字內容。修改後右邊會更新預覽。", bundle: .module)
                .foregroundStyle(Color.okmTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.okmSurfaceSunken, in: RoundedRectangle(cornerRadius: 6))
            Button(String(localized: "改用步驟重新製作", bundle: .module)) {
                chart = .starter
                isTextMode = false
            }
            .help(String(localized: "捨棄目前的圖表內容，從三個步驟的範本開始", bundle: .module))
        }
        .padding(20)
        .background(Color.okmSurface)
    }

    // MARK: 預覽

    private var previewPanel: some View {
        ZStack {
            Color.okmBackground
            if previewFailed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(Color(nsColor: Palette.warning))
                    Text("預覽無法顯示", bundle: .module)
                        .font(.headline)
                    Text(isTextMode ? String(localized: "請檢查圖表內容的寫法。", bundle: .module) : String(localized: "請確認每個步驟都有名稱，連線也都接到存在的步驟。", bundle: .module))
                        .foregroundStyle(Color.okmTextMuted)
                }
                .padding(32)
            } else if let preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: preview.size.width, maxHeight: preview.size.height)
                    .padding(28)
                    .accessibilityLabel(String(localized: "流程圖預覽", bundle: .module))
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
