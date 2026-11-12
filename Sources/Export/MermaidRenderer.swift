import AppKit
import WebKit

enum RenderError: LocalizedError {
    case missingResource(String)
    case invalidDiagram
    case pdfFailed

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): "App 內缺少必要的檔案：\(name)"
        case .invalidDiagram: "流程圖的內容無法繪製"
        case .pdfFailed: "系統沒有產生 PDF"
        }
    }
}

/// 等網頁載入完成的小工具。
@MainActor
final class PageLoader: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func load(_ webView: WKWebView, resource: String) async throws {
        guard let page = Bundle.main.url(forResource: resource, withExtension: "html") else {
            throw RenderError.missingResource("\(resource).html")
        }
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

/// 把 Mermaid 文字畫成向量圖。Mermaid 只有 JavaScript 版，所以用一個不顯示的網頁檢視來畫，
/// 再輸出成 PDF 資料，放大或列印都不會糊。
@MainActor
final class MermaidRenderer {
    static let shared = MermaidRenderer()

    private let webView: WKWebView
    private let loader = PageLoader()
    private var loading: Task<Void, Error>?
    private var queue: Task<Void, Never>?
    private var cache: [String: Data] = [:]

    private init() {
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1600, height: 1200))
        webView.setValue(false, forKey: "drawsBackground")
    }

    func image(for source: String, dark: Bool) async throws -> NSImage {
        let data = try await pdf(for: source, dark: dark)
        guard let image = NSImage(data: data) else { throw RenderError.invalidDiagram }
        return image
    }

    private func pdf(for source: String, dark: Bool) async throws -> Data {
        let key = (dark ? "d:" : "l:") + source
        if let cached = cache[key] { return cached }

        // 網頁裡只有一個繪圖區，一次只能畫一張；排隊依序處理。
        let previous = queue
        let job = Task { @MainActor () throws -> Data in
            await previous?.value
            return try await self.render(source, dark: dark)
        }
        queue = Task { _ = try? await job.value }
        let data = try await job.value
        cache[key] = data
        return data
    }

    private func render(_ source: String, dark: Bool) async throws -> Data {
        if loading == nil {
            loading = Task { try await loader.load(webView, resource: "mermaid") }
        }
        do {
            try await loading?.value
        } catch {
            loading = nil
            throw error
        }

        let result = try? await webView.callAsyncJavaScript(
            "return await renderDiagram(source, theme)",
            arguments: ["source": source, "theme": Self.theme(dark: dark)],
            contentWorld: .page
        )
        guard let size = result as? [String: Any],
              let width = size["width"] as? Double, let height = size["height"] as? Double,
              width > 0, height > 0 else { throw RenderError.invalidDiagram }

        let configuration = WKPDFConfiguration()
        configuration.rect = CGRect(x: 0, y: 0, width: ceil(width), height: ceil(height))
        return try await webView.pdf(configuration: configuration)
    }

    /// 流程圖的顏色也取自 OKM 色票，和文件其他部分一致。
    static func theme(dark: Bool) -> [String: String] {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        var theme: [String: String] = [:]
        appearance.performAsCurrentDrawingAppearance {
            theme = [
                "primaryColor": (dark ? OKMPalette.navy700 : OKMPalette.navy100).hexString,
                "primaryBorderColor": OKMPalette.borderStrong.hexString,
                "primaryTextColor": OKMPalette.text.hexString,
                "lineColor": OKMPalette.textMuted.hexString,
                "secondaryColor": Theme.pageSunken.hexString,
                "tertiaryColor": Theme.canvas.hexString,
                "edgeLabelBackground": Theme.page.hexString,
                "textColor": OKMPalette.text.hexString,
            ]
        }
        return theme
    }
}

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02x%02x%02x",
                      Int(round(rgb.redComponent * 255)), Int(round(rgb.greenComponent * 255)), Int(round(rgb.blueComponent * 255)))
    }
}
