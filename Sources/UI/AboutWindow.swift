import AppKit
import CoreText
import SwiftUI

/// App 的版本與版權，讀自 Info.plist。
enum AppInfo {
    private static var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    static var version: String {
        let short = info["CFBundleShortVersionString"] as? String ?? "—"
        let build = info["CFBundleVersion"] as? String ?? "—"
        return "版本 \(short)（build \(build)）"
    }

    static var copyright: String { info["NSHumanReadableCopyright"] as? String ?? "" }
}

/// 「關於 OKM Mead」：動態 Logo、產品名稱、版本與版權。版面與 OKM Mimir 的關於視窗一致。
@MainActor
enum AboutWindow {
    private static var window: NSWindow?

    static func show() {
        window?.close()
        // 每次開啟都重建，讓動態 Logo 與產品名稱從頭播放。
        let hosting = NSHostingView(rootView: AboutView())
        hosting.sizingOptions = []
        let created = NSWindow(
            contentRect: NSRect(origin: .zero, size: AboutView.size),
            styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false
        )
        created.title = "關於 OKM Mead"
        created.titleVisibility = .hidden
        created.titlebarAppearsTransparent = true
        created.isMovableByWindowBackground = true
        created.isReleasedWhenClosed = false
        created.isOpaque = false
        created.backgroundColor = .clear
        created.contentView = glass(containing: hosting)
        created.setContentSize(AboutView.size)
        created.center()
        window = created
        created.makeKeyAndOrderFront(nil)
    }

    /// macOS 26 以上用 Liquid Glass，較舊的系統退回半透明視窗材質。
    private static func glass(containing content: NSView) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.contentView = content
            return glass
        }
        let material = NSVisualEffectView()
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        content.frame = material.bounds
        content.autoresizingMask = [.width, .height]
        material.addSubview(content)
        return material
    }
}

private struct AboutView: View {
    static let size = NSSize(width: 340, height: 360)

    /// 產品名稱在方塊大致拼成 Logo 之後才淡入。
    private static let wordmarkDelay = LaunchLogoView.duration - 0.5
    private static let wordmarkFade = 0.6

    @State private var wordmarkShown = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    var body: some View {
        VStack(spacing: 0) {
            LaunchLogo { revealWordmark() }
                .frame(width: 120, height: 120)
                .padding(.top, 36)
                .accessibilityHidden(true)
            WordmarkText(size: 22)
                .padding(.top, 18)
                .opacity(wordmarkShown ? 1 : 0)
                .offset(y: wordmarkShown ? 0 : 8)
            Text(AppInfo.version)
                .foregroundStyle(.secondary)
                .padding(.top, 14)
            VStack(spacing: 2) {
                Text(AppInfo.copyright)
                Text("程式採 MIT 授權，Poppins 字型採 SIL OFL 1.1。")
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.top, 6)
            Spacer()
            Button("授權與原始碼") { LicenseWindow.show() }
                .controlSize(.small)
                .padding(.bottom, 24)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private func revealWordmark() {
        withAnimation(.easeOut(duration: Self.wordmarkFade).delay(Self.wordmarkDelay)) { wordmarkShown = true }
    }
}

/// 產品名稱用的 Poppins（SIL OFL 1.1），隨 App 資源打包，第一次使用時註冊到本行程。
enum BrandFont {
    enum Weight: String, CaseIterable {
        case regular = "Poppins-Regular"
        case semibold = "Poppins-SemiBold"
    }

    private static let registration: Void = {
        for weight in Weight.allCases {
            guard let url = Bundle.main.url(forResource: weight.rawValue, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func registerIfNeeded() { registration }
}

/// 文字標誌「OKM MEAD」：全大寫、加大字距；前段粗體（淺色海軍藍、深色白），後段一般粗細灰藍。
struct WordmarkText: View {
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private static let tracking: CGFloat = 0.32

    init(size: CGFloat) {
        self.size = size
        BrandFont.registerIfNeeded()
    }

    var body: some View {
        let primary = colorScheme == .dark ? Color.white : Color(nsColor: OKMPalette.brandNavy)
        let secondary = Color(nsColor: OKMPalette.brandSlate)
        // 最後一個字母不加字距，文字才會置中。
        return (part("OKM ", .semibold, primary, tracked: true)
            + part("MEA", .regular, secondary, tracked: true)
            + part("D", .regular, secondary, tracked: false))
            .accessibilityLabel("OKM Mead")
    }

    private func part(_ string: String, _ weight: BrandFont.Weight, _ color: Color, tracked: Bool) -> Text {
        Text(string)
            .font(.custom(weight.rawValue, fixedSize: size))
            .foregroundColor(color)
            .tracking(tracked ? size * Self.tracking : 0)
    }
}
