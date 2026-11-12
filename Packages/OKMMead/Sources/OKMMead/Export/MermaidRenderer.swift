// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit
import WebKit

enum RenderError: LocalizedError {
    case missingResource(String)
    case invalidDiagram
    case pdfFailed

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): String(localized: "App 內缺少必要的檔案：\(name)", bundle: .module)
        case .invalidDiagram: String(localized: "流程圖的內容無法繪製", bundle: .module)
        case .pdfFailed: String(localized: "系統沒有產生 PDF", bundle: .module)
        }
    }
}

/// 等網頁載入完成的小工具。
@MainActor
final class PageLoader: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    /// 載入內嵌的空白頁，再依序執行 Mermaid（由使用端經 `MeadConfiguration.mermaidScript` 提供）與共用的繪圖函式。
    /// 頁面不從檔案載入，所以讀不到任何本機檔案，也沒有網路來源。
    func load(_ webView: WKWebView, style: String, body: String) async throws {
        guard let mermaidURL = MeadConfiguration.mermaidScript,
              let mermaid = try? String(contentsOf: mermaidURL, encoding: .utf8) else {
            throw RenderError.missingResource("mermaid.js")
        }
        guard let diagramURL = Bundle.module.url(forResource: "diagram", withExtension: "js"),
              let diagram = try? String(contentsOf: diagramURL, encoding: .utf8) else {
            throw RenderError.missingResource("diagram.js")
        }
        let page = "<!doctype html><html lang=\"zh-Hant\"><head><meta charset=\"utf-8\"><style>\(style)</style></head><body>\(body)</body></html>"
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString(page, baseURL: nil)
        }
        // 結尾的 true：腳本最後一個運算式的值若無法轉成原生型別，WebKit 會回報錯誤。
        _ = try await webView.evaluateJavaScript(mermaid + "\n;true")
        _ = try await webView.evaluateJavaScript(diagram + "\n;true")
    }

    /// PDF 與列印用的樣式表。
    static func exportStylesheet() throws -> String {
        guard let url = Bundle.module.url(forResource: "export", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else { throw RenderError.missingResource("export.css") }
        return css
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
            loading = Task {
                try await loader.load(
                    webView, style: "html, body { margin: 0; background: transparent; } #host { display: inline-block; line-height: 0; }",
                    body: "<div id=\"host\"></div>"
                )
            }
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

    /// 流程圖的顏色取自同一組語意色，和文件其他部分一致。
    static func theme(dark: Bool) -> [String: String] {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        var theme: [String: String] = [:]
        appearance.performAsCurrentDrawingAppearance {
            theme = [
                "primaryColor": Theme.tint.hexString,
                "primaryBorderColor": Palette.borderStrong.hexString,
                "primaryTextColor": Palette.text.hexString,
                "lineColor": Palette.textMuted.hexString,
                "secondaryColor": Theme.pageSunken.hexString,
                "tertiaryColor": Theme.canvas.hexString,
                "edgeLabelBackground": Theme.page.hexString,
                "textColor": Palette.text.hexString,
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
