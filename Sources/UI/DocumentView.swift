import SwiftUI

/// 文件視窗：左側大綱、右側紙張、頂部工具列。
struct DocumentView: View {
    @ObservedObject var editor: EditorController
    let documentName: String
    let fileURL: URL?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationSplitView {
            OutlineSidebar(editor: editor)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            Group {
                if editor.isSourceMode {
                    SourceCanvas(editor: editor)
                } else {
                    EditorCanvas(editor: editor)
                }
            }
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
            Button("好") {}
        } message: {
            Text(editor.exportFailure?.message ?? "")
        }
        .containerBackground(for: .window) { WindowGlass() }
        .focusedSceneObject(editor)
        .onAppear {
            editor.documentName = documentName
            editor.fileURL = fileURL
            AppearanceController.shared.apply()
        }
        .onChange(of: documentName) { _, name in editor.documentName = name }
        .onChange(of: fileURL) { _, url in editor.fileURL = url }
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
        editor.isSourceMode || editor.selectionIsAttachment
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("段落樣式", selection: Binding(get: { editor.currentStyle }, set: { editor.setBlockStyle($0) })) {
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
            .help("段落樣式")
        }

        ToolbarItemGroup(placement: .principal) {
            Group {
                Toggle(isOn: Binding(get: { editor.isBold }, set: { _ in editor.toggleBold() })) {
                    Label("粗體", systemImage: "bold")
                }
                .help("粗體（⌘B）")
                Toggle(isOn: Binding(get: { editor.isItalic }, set: { _ in editor.toggleItalic() })) {
                    Label("斜體", systemImage: "italic")
                }
                .help("斜體（⌘I）")

                groupSeparator

                Toggle(isOn: Binding(get: { editor.currentStyle == .bullet }, set: { _ in editor.toggleList(.bullet) })) {
                    Label("項目清單", systemImage: "list.bullet")
                }
                .help("項目清單")
                Toggle(isOn: Binding(get: { editor.currentStyle == .numbered }, set: { _ in editor.toggleList(.numbered) })) {
                    Label("編號清單", systemImage: "list.number")
                }
                .help("編號清單")
                Toggle(isOn: Binding(get: { editor.currentStyle == .todo }, set: { _ in editor.toggleList(.todo) })) {
                    Label("待辦清單", systemImage: "checklist")
                }
                .help("待辦清單：每個項目前面有可以勾選的方框")
            }
            .disabled(formattingDisabled)

            Group {
                Button { editor.changeListIndent(by: -1) } label: {
                    Label("減少縮排", systemImage: "decrease.indent")
                }
                .help("減少縮排（⌘[）")
                Button { editor.changeListIndent(by: 1) } label: {
                    Label("增加縮排", systemImage: "increase.indent")
                }
                .help("增加縮排（⌘]）：清單項目變成上一項的子項目")
            }
            .disabled(formattingDisabled || !editor.currentStyle.isList)

            // 分隔線左邊是「改文字的樣子」，右邊是「放東西進文件」。
            groupSeparator

            Group {
                Button { editor.editLink() } label: {
                    Label("連結", systemImage: "link")
                }
                .disabled(formattingDisabled)
                .help("加入或編輯連結（⌘K）")
                Button { editor.chooseImages() } label: {
                    Label("圖片", systemImage: "photo")
                }
                .help("插入圖片")
                Button { editor.insertTable() } label: {
                    Label("表格", systemImage: "tablecells")
                }
                .help("插入表格")
                Button { editor.insertDiagram() } label: {
                    Label("流程圖", systemImage: "arrow.triangle.branch")
                }
                .help("插入流程圖")
            }
            .disabled(editor.isSourceMode)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Toggle(isOn: Binding(get: { editor.isSourceMode }, set: { _ in editor.toggleSourceMode() })) {
                Label("Markdown 原始格式", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .help(editor.isSourceMode ? "回到排版好的文件" : "顯示 Markdown 原始格式")

            Button { AppearanceController.shared.toggle() } label: {
                Label(colorScheme == .dark ? "淺色模式" : "深色模式",
                      systemImage: colorScheme == .dark ? "sun.max" : "moon")
            }
            .help(colorScheme == .dark ? "切換成淺色模式" : "切換成深色模式")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button { editor.showPrintPreview() } label: {
                if editor.isExporting {
                    ProgressView().controlSize(.small)
                } else {
                    Label("預覽列印", systemImage: "doc.text.magnifyingglass")
                }
            }
            .disabled(editor.isExporting)
            .help("預覽列印：先看分頁後的樣子，再列印或存成 PDF")
        }
    }
}

/// 視窗底層：毛玻璃（透出視窗後方的桌面），上面疊一層半透明的底色。
private struct WindowGlass: View {
    var body: some View {
        ZStack {
            BehindWindowBlur()
            Color.okmCanvasGlass
        }
        .ignoresSafeArea()
    }
}

private struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        // `underWindowBackground` 幾乎不透明，疊再淡的底色也透不出後方；`hudWindow` 才是真正半透明的毛玻璃。
        view.material = .hudWindow
        // 視窗不在最前面時也維持毛玻璃，不退回不透明的底色。
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

private struct OutlineSidebar: View {
    @ObservedObject var editor: EditorController

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
                                .foregroundStyle(isCurrent ? Color.okmAccent : item.level == 3 ? Color.okmTextMuted : Color.okmText)
                        }
                        .padding(.leading, CGFloat(item.level - 1) * 12)
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
                    Text("大綱")
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
            // 系統側欄自己有一層近乎不透明的底；這裡放一層會直接透出視窗後方的毛玻璃，再疊海軍藍。
            ZStack {
                BehindWindowBlur()
                Color.okmSidebarTint
            }
            .ignoresSafeArea()
        }
        .overlay {
            if editor.outline.isEmpty {
                Text("把段落的樣式設成「大標題」或「標題」，就會列在這裡，方便在長文件裡跳到各個段落。")
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
