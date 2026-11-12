// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import SwiftUI

/// 文件裡的流程圖。按兩下或用右上角的按鈕開啟步驟編輯器。
struct DiagramBlockView: View {
    @ObservedObject var model: DiagramModel
    let attachment: DiagramAttachment
    weak var editor: EditorController?
    /// 文字欄的寬度（由附件在量尺寸時帶入）；窄的預覽區依它縮小。
    var availableWidth: CGFloat = 560

    private var isEditable: Bool { editor?.isEditable ?? false }

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: NSImage?
    @State private var failed = false
    @State private var isHovered = false

    /// 流程圖在文件裡的最大顯示尺寸；超過就等比例縮小。
    private static let maxSize = CGSize(width: 560, height: 460)

    private struct RenderKey: Hashable {
        var source: String
        var dark: Bool
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.okmSurfaceSunken.opacity(isHovered ? 0.6 : 0))
            }
            .overlay {
                if let editor { BlockSelectionRing(editor: editor, id: ObjectIdentifier(attachment)) }
            }
            .overlay(alignment: .topTrailing) {
                if let editor, isEditable {
                    DiagramEditButton(editor: editor, attachment: attachment, isHovered: isHovered)
                }
            }
            .contentShape(Rectangle())
            .onHover { isHovered = isEditable && $0 }
            .onTapGesture(count: 2) { if isEditable { editor?.editDiagram(attachment) } }
            .onTapGesture { if isEditable { editor?.selectBlock(attachment) } }
            .contextMenu {
                if isEditable {
                    Button(String(localized: "編輯流程圖…", bundle: .module)) { editor?.editDiagram(attachment) }
                    Divider()
                    Button(String(localized: "刪除流程圖", bundle: .module), role: .destructive) { editor?.deleteBlock(attachment) }
                }
            }
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .task(id: RenderKey(source: model.source, dark: colorScheme == .dark)) {
                await render()
            }
            // 區塊的高度由文字排版決定；圖畫好後要請它重新量一次。
            .onChange(of: image) { requestRelayout() }
            .onChange(of: failed) { requestRelayout() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "流程圖", bundle: .module))
            .accessibilityHint(isEditable ? String(localized: "按兩下可以編輯", bundle: .module) : "")
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            // 明確給定顯示尺寸：文字排版量到的高度和實際畫出來的才會一致，圖不會被切掉。
            let scale = min(1, min(Self.maxSize.width, availableWidth) / image.size.width, Self.maxSize.height / image.size.height)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: image.size.width * scale)
                .frame(height: image.size.height * scale)
        } else if failed {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(Color(nsColor: Palette.warning))
                Text("這張流程圖的內容無法顯示", bundle: .module)
                    .foregroundStyle(Color.okmText)
                if isEditable { Button(String(localized: "打開來修正", bundle: .module)) { editor?.editDiagram(attachment) } }
            }
            .frame(height: 130)
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(height: 130)
        }
    }

    /// 滑鼠移上來或區塊被選取時都顯示，只用鍵盤的人也找得到。
    private struct DiagramEditButton: View {
        @ObservedObject var editor: EditorController
        let attachment: DiagramAttachment
        let isHovered: Bool

        var body: some View {
            let isVisible = isHovered || editor.selectedAttachment == ObjectIdentifier(attachment)
            Button(String(localized: "編輯流程圖", bundle: .module)) { editor.editDiagram(attachment) }
                .controlSize(.small)
                .padding(8)
                .opacity(isVisible ? 1 : 0)
                .accessibilityHidden(!isVisible)
        }
    }

    private func requestRelayout() {
        DispatchQueue.main.async { editor?.relayoutBlock(attachment) }
    }

    private func render() async {
        do {
            let rendered = try await MermaidRenderer.shared.image(for: model.source, dark: colorScheme == .dark)
            image = rendered
            failed = false
        } catch is CancellationError {
        } catch {
            image = nil
            failed = true
        }
    }
}
