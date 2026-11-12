import XCTest
@testable import OKMMead

@MainActor
final class ImageTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("okm-mead-image-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    /// 在 `sub` 資料夾裡產生一張指定顏色的小圖。
    private func makeImage(_ name: String, in sub: String, color: NSColor) throws -> URL {
        let directory = folder.appendingPathComponent(sub)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        NSGraphicsContext.restoreGraphicsState()
        let url = directory.appendingPathComponent(name)
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path)
    }

    /// 圖片在背景執行緒複製（文件可能在網路磁碟上）；等它出現，最多三秒。
    private func appears(_ path: String) -> Bool {
        let deadline = Date().addingTimeInterval(3)
        while !exists(path), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        return exists(path)
    }

    func testStandaloneImageSurvivesRoundTrip() {
        let source = "前言\n\n![流程 示意](md.img/flow.png)\n\n結尾\n"
        let text = MarkdownImporter.attributedString(from: source)
        var images = 0
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if value is ImageAttachment { images += 1 }
        }
        XCTAssertEqual(images, 1, "獨立一段的圖片應該變成圖片區塊")
        XCTAssertEqual(MarkdownExporter.markdown(from: text), source)
    }

    func testInlineImageIsKeptAsWritten() {
        let source = "文字 ![圖](a.png) 文字\n"
        XCTAssertEqual(MarkdownExporter.markdown(from: MarkdownImporter.attributedString(from: source)), source)
    }

    func testImageIsCopiedNextToSavedDocument() throws {
        let source = try makeImage("照片 (1).png", in: "來源", color: .red)
        let editor = EditorController(markdown: "內文\n")
        editor.fileURL = folder.appendingPathComponent("doc/文件.md")
        editor.insertImage(from: source)
        XCTAssertTrue(appears("doc/md.img/照片-1.png"), "已存檔的文件應該隨即把圖片複製到 md.img")
        XCTAssertEqual(editor.markdown, "內文\n\n![照片 (1)](md.img/照片-1.png)\n")
        XCTAssertEqual(editor.imageURL(for: "md.img/照片-1.png")?.path, folder.appendingPathComponent("doc/md.img/照片-1.png").path)
    }

    func testImageWaitsUntilDocumentIsSaved() throws {
        let source = try makeImage("a.png", in: "來源", color: .red)
        let editor = EditorController(markdown: "")
        editor.insertImage(from: source)
        XCTAssertEqual(editor.markdown, "![a](md.img/a.png)\n")
        XCTAssertEqual(editor.imageURL(for: "md.img/a.png"), source, "存檔前先顯示原始檔案")
        XCTAssertFalse(exists("doc/md.img/a.png"))

        editor.fileURL = folder.appendingPathComponent("doc/文件.md")
        XCTAssertTrue(appears("doc/md.img/a.png"), "存檔後才複製")
        XCTAssertTrue(exists("來源/a.png"), "原始檔案留在原處")
    }

    func testSameNameDifferentContentGetsNewNameAndNeverOverwrites() throws {
        let red = try makeImage("a.png", in: "紅", color: .red)
        let blue = try makeImage("a.png", in: "藍", color: .blue)
        let editor = EditorController(markdown: "")
        editor.fileURL = folder.appendingPathComponent("doc/文件.md")
        editor.insertImage(from: red)
        editor.insertImage(from: blue)
        editor.insertImage(from: red)
        XCTAssertEqual(editor.markdown, "![a](md.img/a.png)\n\n![a](md.img/a-2.png)\n\n![a](md.img/a.png)\n")
        XCTAssertTrue(appears("doc/md.img/a.png") && appears("doc/md.img/a-2.png"))
        XCTAssertTrue(FileManager.default.contentsEqual(atPath: folder.appendingPathComponent("doc/md.img/a.png").path, andPath: red.path))
        XCTAssertTrue(FileManager.default.contentsEqual(atPath: folder.appendingPathComponent("doc/md.img/a-2.png").path, andPath: blue.path))
    }

    func testSaveAsBringsImagesAlong() throws {
        let source = try makeImage("a.png", in: "來源", color: .red)
        let editor = EditorController(markdown: "")
        editor.fileURL = folder.appendingPathComponent("舊/文件.md")
        editor.insertImage(from: source)
        editor.fileURL = folder.appendingPathComponent("新/文件.md")
        XCTAssertTrue(appears("新/md.img/a.png"), "另存到別處時圖片要跟著過去")
        XCTAssertTrue(appears("舊/md.img/a.png"))
    }

    func testExportEmbedsImages() throws {
        let source = try makeImage("a.png", in: "來源", color: .red)
        let html = PDFExporter.embedImages(["md.img/a.png": source], in: "<p><img src=\"md.img/a.png\" alt=\"a\" /></p>")
        XCTAssertTrue(html.contains("src=\"data:image/png;base64,"))
    }
}
