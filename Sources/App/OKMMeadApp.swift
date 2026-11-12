import OKMMead
import SwiftUI

@main
struct OKMMeadApp: App {
    init() {
        // 啟動時直接給一份空白文件，而不是「打開」檔案的面板。
        // 面板一旦被取消，App 會在沒有任何視窗的狀態下繼續執行，看起來像沒有啟動。
        UserDefaults.standard.register(defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
        Updater.shared.start()
        #if DEBUG
        // 截圖驗收用：OKMMEAD_SHOW_ABOUT=1 時啟動後直接開啟關於視窗。
        if ProcessInfo.processInfo.environment["OKMMEAD_SHOW_ABOUT"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                AboutWindow.show()
                LicenseWindow.show()
            }
        }
        // 驗收用：OKMMEAD_IMAGE_CHECK=<圖片>|<存檔位置>。插入圖片後把未命名文件存到指定位置，
        // 確認存檔後圖片真的被複製到旁邊的 md.img（走的是和使用者按「儲存」相同的路徑）。
        if let check = ProcessInfo.processInfo.environment["OKMMEAD_IMAGE_CHECK"]?.split(separator: "|").map(String.init),
           check.count == 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard let document = NSDocumentController.shared.documents.first, let editor = Self.lastEditor
                else { print("IMAGE_CHECK 找不到文件"); return }
                editor.insertImage(from: URL(fileURLWithPath: check[0]))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    document.save(to: URL(fileURLWithPath: check[1]), ofType: document.fileType ?? "", for: .saveAsOperation) { error in
                        print("IMAGE_CHECK saved", error?.localizedDescription ?? "ok")
                    }
                }
            }
        }
        #endif
    }

    #if DEBUG
    /// 最近一次顯示的文件的編輯器（驗收用）。
    @MainActor static weak var lastEditor: EditorController?
    #endif

    var body: some Scene {
        DocumentGroup(newDocument: { MeadDocument() }) { file in
            DocumentView(
                editor: Self.track(file.document.editor),
                documentName: file.fileURL?.deletingPathExtension().lastPathComponent ?? "未命名",
                fileURL: file.fileURL
            )
            .frame(minWidth: 760, minHeight: 480)
            .tint(.okmAccent)
        }
        .defaultSize(width: 1180, height: 820)
        .commands { MeadCommands() }
    }
}

extension OKMMeadApp {
    @MainActor static func track(_ editor: EditorController) -> EditorController {
        #if DEBUG
        lastEditor = editor
        #endif
        return editor
    }
}

/// 選單列指令。每個工具列功能在這裡都有對應項目與快速鍵，只用鍵盤也能完成所有操作。
struct MeadCommands: Commands {
    @FocusedObject private var editor: EditorController?

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("關於 OKM Mead") { AboutWindow.show() }
            Button("檢查更新…") { Updater.shared.checkForUpdates() }
                .disabled(!Updater.shared.isAvailable)
        }
        CommandGroup(replacing: .importExport) {
            Button("轉成 PDF…") { editor?.exportPDF() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(editor == nil)
        }
        CommandGroup(after: .sidebar) {
            Button("Markdown 原始格式") { editor?.toggleSourceMode() }
                .keyboardShortcut("/", modifiers: [.command, .option])
                .disabled(editor == nil)
            Menu("外觀") {
                Button("跟隨系統") { AppearanceController.shared.set(.system) }
                Button("淺色") { AppearanceController.shared.set(.light) }
                Button("深色") { AppearanceController.shared.set(.dark) }
            }
            Divider()
        }
        CommandGroup(replacing: .printItem) {
            Button("預覽列印…") { editor?.showPrintPreview() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(editor == nil)
            Button("列印…") { editor?.printDocument() }
                .keyboardShortcut("p")
                .disabled(editor == nil)
        }

        CommandMenu("格式") {
            Button("大標題") { editor?.setBlockStyle(.title) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("標題") { editor?.setBlockStyle(.heading) }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("小標題") { editor?.setBlockStyle(.subheading) }
                .keyboardShortcut("3", modifiers: [.command, .option])
            Button("內文") { editor?.setBlockStyle(.body) }
                .keyboardShortcut("0", modifiers: [.command, .option])
            Button("引言") { editor?.setBlockStyle(.quote) }
            Divider()
            Button("項目清單") { editor?.toggleList(.bullet) }
                .keyboardShortcut("8", modifiers: [.command, .shift])
            Button("編號清單") { editor?.toggleList(.numbered) }
                .keyboardShortcut("7", modifiers: [.command, .shift])
            Button("待辦清單") { editor?.toggleList(.todo) }
                .keyboardShortcut("9", modifiers: [.command, .shift])
            Button("增加縮排") { editor?.changeListIndent(by: 1) }
                .keyboardShortcut("]")
            Button("減少縮排") { editor?.changeListIndent(by: -1) }
                .keyboardShortcut("[")
            Divider()
            Button("粗體") { editor?.toggleBold() }
                .keyboardShortcut("b")
            Button("斜體") { editor?.toggleItalic() }
                .keyboardShortcut("i")
            Button("刪除線") { editor?.toggleStrikethrough() }
                .keyboardShortcut("x", modifiers: [.command, .shift])
        }

        CommandMenu("插入") {
            Button("連結…") { editor?.editLink() }
                .keyboardShortcut("k")
            Divider()
            Button("圖片…") { editor?.chooseImages() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Button("表格") { editor?.insertTable() }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Button("流程圖…") { editor?.insertDiagram() }
                .keyboardShortcut("f", modifiers: [.command, .option])
            Button("分隔線") { editor?.insertDivider() }
        }
    }
}
