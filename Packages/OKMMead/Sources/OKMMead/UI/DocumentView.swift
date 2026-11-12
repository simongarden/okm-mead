// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import SwiftUI

/// 文件視窗的內容：左側大綱、右側紙張、頂部工具列。放進 `NSHostingController` 當視窗的內容即可使用。
public struct MeadDocumentView: View {
    @ObservedObject var editor: EditorController
    private let drawsCanvasBackground: Bool
    private let showsMenuOnlyCommands: Bool
    private let sidebarBackground: AnyView?
    private let trailingToolbar: AnyView?

    /// - Parameters:
    ///   - drawsCanvasBackground: 紙張後面是否鋪上 `MeadAppearance.canvas`；使用端要自己提供視窗底層（例如毛玻璃）時設為 false。
    ///   - showsMenuOnlyCommands: 工具列是否加上刪除線與分隔線。主選單已有這兩項的使用端不需要；沒有對應選單的使用端設為 true。
    ///   - sidebarBackground: 取代大綱側欄預設底色（`MeadAppearance.sidebar`）的底層。
    ///   - trailingToolbar: 加在工具列右側、「Markdown 原始格式」之後的項目（例如外觀切換）。
    public init(editor: EditorController, drawsCanvasBackground: Bool = true, showsMenuOnlyCommands: Bool = false, sidebarBackground: AnyView? = nil, trailingToolbar: AnyView? = nil) {
        self.editor = editor
        self.drawsCanvasBackground = drawsCanvasBackground
        self.showsMenuOnlyCommands = showsMenuOnlyCommands
        self.sidebarBackground = sidebarBackground
        self.trailingToolbar = trailingToolbar
    }

    public var body: some View {
        NavigationSplitView {
            OutlineSidebar(editor: editor, background: sidebarBackground)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            Group {
                if editor.isSourceMode {
                    SourceCanvas(editor: editor)
                } else {
                    EditorCanvas(editor: editor)
                }
            }
            .background(drawsCanvasBackground ? Color.okmBackground : Color.clear)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .toolbar { toolbar }
        .sheet(item: $editor.diagramBeingEdited) { request in
            FlowchartEditor(request: request) { source in
                editor.finishDiagramEdit(request, source: source)
            }
        }
        .sheet(item: $editor.printPreview) { item in
            PrintPreviewSheet(
                item: item,
                onPrint: { editor.printPreview = nil; editor.printDocument() },
                onSave: { editor.printPreview = nil; editor.exportPDF() },
                onClose: { editor.printPreview = nil }
            )
        }
        .alert(editor.exportFailure?.title ?? "", isPresented: failureBinding) {
            Button(String(localized: "好", bundle: .module)) {}
        } message: {
            Text(editor.exportFailure?.message ?? "")
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(get: { editor.exportFailure != nil }, set: { if !$0 { editor.exportFailure = nil } })
    }

    /// 工具列裡的 `Divider()` 會被畫成橫線，所以自己畫一條直的細線。
    private var groupSeparator: some View {
        Rectangle()
            .fill(Color.okmBorderStrong.opacity(0.45))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
    }

    /// 原始格式下沒有樣式可言，游標在表格或流程圖上時也一樣。
    private var formattingDisabled: Bool {
        editor.isSourceMode || editor.selectionIsAttachment || editor.isEditingCell
    }

    /// 粗體、斜體、連結在表格儲存格裡也能用；段落樣式與清單不行。
    private var inlineFormattingDisabled: Bool {
        editor.isSourceMode || (editor.selectionIsAttachment && !editor.isEditingCell)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker(String(localized: "段落樣式", bundle: .module), selection: Binding(get: { editor.currentStyle }, set: { editor.setBlockStyle($0) })) {
                ForEach(BlockStyle.pickable, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
                if editor.currentStyle == .code {
                    Text(BlockStyle.code.displayName).tag(BlockStyle.code)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 112)
            .disabled(formattingDisabled)
            .help(String(localized: "段落樣式", bundle: .module))
        }

        ToolbarItemGroup(placement: .principal) {
            Group {
                Toggle(isOn: Binding(get: { editor.isBold }, set: { _ in editor.toggleBold() })) {
                    Label(String(localized: "粗體", bundle: .module), systemImage: "bold")
                }
                .help(String(localized: "粗體（⌘B）", bundle: .module))
                Toggle(isOn: Binding(get: { editor.isItalic }, set: { _ in editor.toggleItalic() })) {
                    Label(String(localized: "斜體", bundle: .module), systemImage: "italic")
                }
                .help(String(localized: "斜體（⌘I）", bundle: .module))
                if showsMenuOnlyCommands {
                    Toggle(isOn: Binding(get: { editor.isStrikethrough }, set: { _ in editor.toggleStrikethrough() })) {
                        Label(String(localized: "刪除線", bundle: .module), systemImage: "strikethrough")
                    }
                    .help(String(localized: "刪除線（⇧⌘X）", bundle: .module))
                }
            }
            .disabled(inlineFormattingDisabled)

            Group {
                groupSeparator

                Toggle(isOn: Binding(get: { editor.currentStyle == .bullet }, set: { _ in editor.toggleList(.bullet) })) {
                    Label(String(localized: "項目清單", bundle: .module), systemImage: "list.bullet")
                }
                .help(String(localized: "項目清單", bundle: .module))
                Toggle(isOn: Binding(get: { editor.currentStyle == .numbered }, set: { _ in editor.toggleList(.numbered) })) {
                    Label(String(localized: "編號清單", bundle: .module), systemImage: "list.number")
                }
                .help(String(localized: "編號清單", bundle: .module))
                Toggle(isOn: Binding(get: { editor.currentStyle == .todo }, set: { _ in editor.toggleList(.todo) })) {
                    Label(String(localized: "待辦清單", bundle: .module), systemImage: "checklist")
                }
                .help(String(localized: "待辦清單：每個項目前面有可以勾選的方框", bundle: .module))
            }
            .disabled(formattingDisabled)

            Group {
                Button { editor.changeListIndent(by: -1) } label: {
                    Label(String(localized: "減少縮排", bundle: .module), systemImage: "decrease.indent")
                }
                .help(String(localized: "減少縮排（⌘[）", bundle: .module))
                Button { editor.changeListIndent(by: 1) } label: {
                    Label(String(localized: "增加縮排", bundle: .module), systemImage: "increase.indent")
                }
                .help(String(localized: "增加縮排（⌘]）：清單項目變成上一項的子項目", bundle: .module))
            }
            .disabled(formattingDisabled || !editor.currentStyle.isList)

            // 分隔線左邊是「改文字的樣子」，右邊是「放東西進文件」。
            groupSeparator

            Group {
                Button { editor.editLink() } label: {
                    Label(String(localized: "連結", bundle: .module), systemImage: "link")
                }
                .disabled(inlineFormattingDisabled)
                .help(String(localized: "加入或編輯連結（⌘K）", bundle: .module))
                Button { editor.chooseImages() } label: {
                    Label(String(localized: "圖片", bundle: .module), systemImage: "photo")
                }
                .help(String(localized: "插入圖片", bundle: .module))
                Button { editor.insertTable() } label: {
                    Label(String(localized: "表格", bundle: .module), systemImage: "tablecells")
                }
                .help(String(localized: "插入表格", bundle: .module))
                Button { editor.insertDiagram() } label: {
                    Label(String(localized: "流程圖", bundle: .module), systemImage: "arrow.triangle.branch")
                }
                .help(String(localized: "插入流程圖", bundle: .module))
                if showsMenuOnlyCommands {
                    Button { editor.insertDivider() } label: {
                        Label(String(localized: "分隔線", bundle: .module), systemImage: "minus")
                    }
                    .help(String(localized: "插入分隔線", bundle: .module))
                }
            }
            .disabled(editor.isSourceMode)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Toggle(isOn: Binding(get: { editor.isSourceMode }, set: { _ in editor.toggleSourceMode() })) {
                Label(String(localized: "Markdown 原始格式", bundle: .module), systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .help(editor.isSourceMode ? String(localized: "回到排版好的文件", bundle: .module) : String(localized: "顯示 Markdown 原始格式", bundle: .module))

            if let trailingToolbar { trailingToolbar }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button { editor.showPrintPreview() } label: {
                if editor.isExporting {
                    ProgressView().controlSize(.small)
                } else {
                    Label(String(localized: "預覽列印", bundle: .module), systemImage: "doc.text.magnifyingglass")
                }
            }
            .disabled(editor.isExporting)
            .help(String(localized: "預覽列印：先看分頁後的樣子，再列印或存成 PDF", bundle: .module))
        }
    }
}

private struct OutlineSidebar: View {
    @ObservedObject var editor: EditorController
    let background: AnyView?

    /// 每個項目上下各加的留白；加大後項目之間較疏，分隔線也有位置。
    private static let rowPadding: CGFloat = 5

    var body: some View {
        List {
            Section {
                ForEach(editor.outline) { item in
                    let isCurrent = item.id == editor.currentOutlineID
                    let isLast = item.id == editor.outline.last?.id
                    Button { editor.jump(to: item) } label: {
                        HStack(spacing: 5) {
                            // 每一列都留同樣的位置給三角形，選取時文字才不會左右移動。
                            Image(systemName: "arrowtriangle.right.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(Color.okmAccent)
                                .opacity(isCurrent ? 1 : 0)
                                .accessibilityHidden(true)
                            Text(item.title)
                                .lineLimit(1)
                                .fontWeight(item.level == 1 || isCurrent ? .semibold : .regular)
                                .foregroundStyle(isCurrent ? Color.okmAccent : item.level >= 3 ? Color.okmTextMuted : Color.okmText)
                        }
                        .padding(.leading, CGFloat(min(item.level, 4) - 1) * 12)
                        .padding(.vertical, Self.rowPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // 項目之間的淺色分隔線；最後一項下面不畫。
                    .overlay(alignment: .bottom) {
                        if !isLast {
                            Rectangle()
                                .fill(Color.okmBorderStrong.opacity(0.22))
                                .frame(height: 1)
                                .offset(y: 4)
                                .accessibilityHidden(true)
                        }
                    }
                    // 目前所在的段落只用粗體與強調色標示，不加底色。
                    .listRowBackground(Color.clear)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            } header: {
                // 標題下的灰線把「大綱」這個名稱和文章的段落標題分開。
                VStack(alignment: .leading, spacing: 6) {
                    Text("大綱", bundle: .module)
                    Rectangle()
                        .fill(Color.okmBorderStrong.opacity(0.55))
                        .frame(height: 1)
                        // 右端和下面項目的分隔線切齊。
                        .padding(.trailing, 20)
                        .accessibilityHidden(true)
                }
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        // 底色沒有形狀，鋪滿整個側欄（含上方視窗按鈕那一段），不畫成圓角矩形。
        .background {
            if let background { background.ignoresSafeArea() } else { Color.okmSidebarTint.ignoresSafeArea() }
        }
        .overlay {
            if editor.outline.isEmpty {
                Text("把段落的樣式設成「大標題」或「標題」，就會列在這裡，方便在長文件裡跳到各個段落。", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Color.okmTextMuted)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 18)
            }
        }
    }
}

private struct SourceCanvas: NSViewRepresentable {
    let editor: EditorController

    func makeNSView(context: Context) -> NSScrollView {
        editor.sourceScrollView.removeFromSuperview()
        return editor.sourceScrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {}
}

private struct EditorCanvas: NSViewRepresentable {
    let editor: EditorController

    func makeNSView(context: Context) -> NSScrollView {
        editor.scrollView.removeFromSuperview()
        return editor.scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {}
}
