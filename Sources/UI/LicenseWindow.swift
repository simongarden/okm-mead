import AppKit
import SwiftUI

/// App 內附的第三方元件。授權全文在 App 資源的 `LICENSE-<名稱>.txt`。
struct LicenseComponent: Identifiable {
    let name: String
    let license: String
    var id: String { name }

    static let all: [LicenseComponent] = [
        .init(name: "swift-markdown", license: "Apache-2.0"),
        .init(name: "swift-cmark", license: "BSD-2-Clause"),
        .init(name: "Mermaid", license: "MIT"),
        .init(name: "Poppins", license: "OFL-1.1"),
    ]

    var text: String? {
        Bundle.main.url(forResource: "LICENSE-\(name)", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}

/// 「授權與原始碼」：本程式的授權、商標聲明與第三方元件；點一下項目，以文字視窗開啟全文。
@MainActor
enum LicenseWindow {
    private static var window: NSWindow?

    static func show() {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let hosting = NSHostingController(rootView: LicenseView { window?.close() })
        hosting.sizingOptions = []
        let created = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 480),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        created.title = "授權與原始碼"
        created.isReleasedWhenClosed = false
        created.contentViewController = hosting
        created.setContentSize(NSSize(width: 460, height: 480))
        created.center()
        window = created
        created.makeKeyAndOrderFront(nil)
    }
}

private struct LicenseView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("OKM Mead").font(.title3.bold())
                Text(AppInfo.version).font(.callout).foregroundStyle(.secondary)
                Text(AppInfo.copyright).font(.callout).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                LinkRow(title: "授權", detail: "MIT", showsDivider: true) {
                    TextDocumentWindow.show(title: "授權", text: Self.bundled("LICENSE", nil))
                }
                LinkRow(title: "商標與官方圖形", detail: nil, showsDivider: true) {
                    TextDocumentWindow.show(title: "商標與官方圖形", text: Self.bundled("TRADEMARKS", "md"))
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("原始碼")
                        Text("程式採 MIT 授權。名稱、商標與官方圖形保留權利。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("取得原始碼") { NSWorkspace.shared.open(Self.sourceURL) }
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            Text("第三方元件").font(.headline)
            VStack(spacing: 0) {
                ForEach(LicenseComponent.all) { component in
                    LinkRow(title: component.name, detail: component.license,
                            showsDivider: component.id != LicenseComponent.all.last?.id) {
                        TextDocumentWindow.show(title: "\(component.name) 授權", text: component.text ?? Self.missing)
                    }
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            Text("點一下項目，以文字視窗開啟對應的授權全文。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                Button("拷貝全部授權文字", action: copyAll)
                Spacer()
                Button("完成", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private static let sourceURL = URL(string: "https://github.com/simongarden/okm-mead")!
    private static let missing = "這個建置沒有內附授權文件。"

    private static func bundled(_ name: String, _ ext: String?) -> String {
        Bundle.main.url(forResource: name, withExtension: ext)
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? missing
    }

    private func copyAll() {
        let own = "===== OKM Mead（MIT） =====\n\(Self.bundled("LICENSE", nil))\n\n"
            + "===== 商標與官方圖形 =====\n\(Self.bundled("TRADEMARKS", "md"))\n\n"
        let text = own + LicenseComponent.all
            .map { "===== \($0.name)（\($0.license)） =====\n\($0.text ?? "")" }
            .joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// 可點擊的列：名稱、右側說明與 ›。
private struct LinkRow: View {
    let title: String
    let detail: String?
    let showsDivider: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let detail { Text(verbatim: detail).foregroundStyle(.secondary) }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showsDivider { Divider().padding(.leading, 12) }
        }
    }
}

/// 唯讀文字視窗（授權全文）。
@MainActor
enum TextDocumentWindow {
    private static var windows: [String: NSWindow] = [:]

    static func show(title: String, text: String) {
        if let window = windows[title] { window.makeKeyAndOrderFront(nil); return }
        let view = NSTextView()
        view.isEditable = false
        view.isRichText = false
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = NSSize(width: 16, height: 16)
        view.string = text
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = view
        let created = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        created.title = title
        created.isReleasedWhenClosed = false
        created.contentView = scroll
        created.center()
        windows[title] = created
        created.makeKeyAndOrderFront(nil)
    }
}
