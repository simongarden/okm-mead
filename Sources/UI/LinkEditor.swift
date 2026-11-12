import SwiftUI

/// 游標旁的連結小視窗：填顯示文字與網址。
struct LinkEditor: View {
    @State var text: String
    @State var address: String
    let isExisting: Bool
    let onCommit: (String, URL) -> Void
    let onRemove: () -> Void
    let onOpen: (URL) -> Void

    private enum Field { case text, address }
    @FocusState private var focus: Field?

    private var url: URL? { Self.normalizedURL(address) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("顯示文字").foregroundStyle(Color.okmTextMuted)
                    TextField("顯示文字", text: $text, prompt: Text("留空會直接顯示網址"))
                        .focused($focus, equals: .text)
                }
                GridRow {
                    Text("網址").foregroundStyle(Color.okmTextMuted)
                    TextField("網址", text: $address, prompt: Text("example.com"))
                        .focused($focus, equals: .address)
                }
            }
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
            .onSubmit(commit)

            HStack {
                if isExisting {
                    Button("移除連結", role: .destructive, action: onRemove)
                    Button("打開") { if let url { onOpen(url) } }
                        .disabled(url == nil)
                }
                Spacer()
                Button("完成", action: commit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(url == nil)
            }
        }
        .padding(16)
        .frame(width: 340)
        .onAppear { focus = text.isEmpty || !address.isEmpty ? (address.isEmpty ? .address : .text) : .address }
    }

    private func commit() {
        guard let url else { return }
        onCommit(text.trimmingCharacters(in: .whitespaces), url)
    }

    /// 使用者通常只打「example.com」；沒有通訊協定時補上 https。
    static func normalizedURL(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let hasScheme = trimmed.contains("://") || trimmed.lowercased().hasPrefix("mailto:")
        guard let url = URL(string: hasScheme ? trimmed : "https://" + trimmed) else { return nil }
        if url.scheme?.lowercased() == "mailto" { return url }
        guard let host = url.host(), host.contains(".") || host == "localhost" else { return nil }
        return url
    }
}
