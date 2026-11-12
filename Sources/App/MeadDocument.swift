import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdownDocument = UTType(importedAs: "net.daringfireball.markdown")
}

/// 一個 `.md` 檔。檔案內容只在開啟時讀一次，之後以編輯器裡的內容為準。
final class MeadDocument: ReferenceFileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.markdownDocument, .plainText] }
    static var writableContentTypes: [UTType] { [.markdownDocument] }

    private let initialMarkdown: String
    private let snapshotBox: MarkdownSnapshot
    @MainActor private var cachedEditor: EditorController?

    init() {
        initialMarkdown = ""
        snapshotBox = MarkdownSnapshot("")
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        initialMarkdown = try Self.decode(data)
        snapshotBox = MarkdownSnapshot(initialMarkdown)
    }

    @MainActor var editor: EditorController {
        if let cachedEditor { return cachedEditor }
        let created = EditorController(markdown: initialMarkdown, snapshot: snapshotBox)
        cachedEditor = created
        return created
    }

    /// 自動儲存時，AppKit 讓主執行緒停下來等這個快照，再從背景執行緒呼叫這裡。
    /// 這裡不能碰編輯器（它屬於主執行緒，而主執行緒正在等我們），只能讀編輯器事先算好的結果。
    func snapshot(contentType: UTType) throws -> String {
        snapshotBox.value
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(snapshot.utf8))
    }

    /// 存檔一律 UTF-8；讀檔時也接受舊文件常見的 Big5。
    private static func decode(_ data: Data) throws -> String {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8.hasPrefix("\u{FEFF}") ? String(utf8.dropFirst()) : utf8
        }
        let big5 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.big5.rawValue)))
        if let text = String(data: data, encoding: big5) { return text }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }
}

/// 目前文件內容的 Markdown。編輯器在主執行緒寫入，存檔在背景執行緒讀取。
final class MarkdownSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: String

    init(_ initial: String) {
        storage = initial
    }

    var value: String {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}
