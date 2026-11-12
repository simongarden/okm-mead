import OKMMead
import SwiftUI

/// 文件視窗：編輯核心的文件視圖，加上這個 App 的視窗底層（毛玻璃）與外觀切換。
struct DocumentView: View {
    @ObservedObject var editor: EditorController
    let documentName: String
    let fileURL: URL?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        MeadDocumentView(
            editor: editor,
            // 畫布底色由視窗底層的毛玻璃提供。
            drawsCanvasBackground: false,
            sidebarBackground: AnyView(SidebarGlass()),
            trailingToolbar: AnyView(appearanceToggle)
        )
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

    private var appearanceToggle: some View {
        Button { AppearanceController.shared.toggle() } label: {
            Label(colorScheme == .dark ? "淺色模式" : "深色模式",
                  systemImage: colorScheme == .dark ? "sun.max" : "moon")
        }
        .help(colorScheme == .dark ? "切換成淺色模式" : "切換成深色模式")
    }
}

/// 視窗底層：毛玻璃（透出視窗後方的桌面），上面疊一層半透明的底色。
private struct WindowGlass: View {
    var body: some View {
        ZStack {
            BehindWindowBlur()
            Color(nsColor: AppTheme.canvasGlass)
        }
        .ignoresSafeArea()
    }
}

/// 系統側欄自己有一層近乎不透明的底；這裡放一層會直接透出視窗後方的毛玻璃，再疊海軍藍。
private struct SidebarGlass: View {
    var body: some View {
        ZStack {
            BehindWindowBlur()
            Color(nsColor: AppTheme.sidebarTint)
        }
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
