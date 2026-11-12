import AppKit
import Markdown
import UniformTypeIdentifiers
import WebKit

/// 轉成 PDF 與列印。文件先轉成 HTML 交給 WebKit 分頁排版，表格跨頁、流程圖向量輸出都由它處理。
@MainActor
enum PDFExporter {
    /// A4，單位為點。
    private static let paperSize = NSSize(width: 595.28, height: 841.89)
    private static let margin: CGFloat = 62

    static func export(markdown: String, images: [String: URL] = [:], to url: URL, window: NSWindow) async throws {
        let info = printInfo()
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        try await run(markdown: markdown, images: images, info: info, window: window, showsPanel: false)
    }

    static func print(markdown: String, images: [String: URL] = [:], window: NSWindow) async throws {
        try await run(markdown: markdown, images: images, info: printInfo(), window: window, showsPanel: true)
    }

    private static func printInfo() -> NSPrintInfo {
        let info = NSPrintInfo()
        info.paperSize = paperSize
        info.topMargin = margin
        info.bottomMargin = margin
        info.leftMargin = margin
        info.rightMargin = margin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        return info
    }

    private static func run(markdown: String, images: [String: URL], info: NSPrintInfo, window: NSWindow, showsPanel: Bool) async throws {
        let contentWidth = paperSize.width - margin * 2
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: paperSize.height - margin * 2))
        let loader = PageLoader()
        try await loader.load(webView, resource: "export")

        let html = embedImages(images, in: HTMLFormatter.format(markdown))
        _ = try await webView.callAsyncJavaScript(
            "return await fill(html, theme)",
            arguments: ["html": html, "theme": MermaidRenderer.theme(dark: false)],
            contentWorld: .page
        )

        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = showsPanel
        operation.showsProgressPanel = showsPanel
        operation.view?.frame = NSRect(origin: .zero, size: NSSize(width: contentWidth, height: paperSize.height - margin * 2))

        let completion = PrintCompletion()
        let succeeded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            completion.continuation = continuation
            operation.runModal(
                for: window, delegate: completion,
                didRun: #selector(PrintCompletion.printOperationDidRun(_:success:contextInfo:)), contextInfo: nil
            )
        }
        // 列印對話框按「取消」不算錯誤；只有存成 PDF 失敗才回報。
        if !succeeded, !showsPanel { throw RenderError.pdfFailed }
    }
}

extension PDFExporter {
    /// 排版用的網頁讀不到文件旁邊的檔案，所以把圖片直接內嵌進 HTML。
    static func embedImages(_ images: [String: URL], in html: String) -> String {
        var result = html
        for (path, url) in images {
            guard let data = try? Data(contentsOf: url) else { continue }
            let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
            let escaped = path.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
            result = result.replacingOccurrences(
                of: "src=\"\(escaped)\"", with: "src=\"data:\(type);base64,\(data.base64EncodedString())\"")
        }
        return result
    }
}

/// AppKit 在背景執行緒回報列印結果，所以這個物件不能綁在主執行緒上。
private final class PrintCompletion: NSObject, @unchecked Sendable {
    var continuation: CheckedContinuation<Bool, Never>?

    @objc func printOperationDidRun(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        continuation?.resume(returning: success)
        continuation = nil
    }
}
