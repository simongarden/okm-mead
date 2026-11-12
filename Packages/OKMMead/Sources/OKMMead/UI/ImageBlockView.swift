// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import SwiftUI

/// 文件裡的圖片。檔案放在文件旁邊的 `md.img` 資料夾，Markdown 裡只記相對路徑。
struct ImageBlockView: View {
    @ObservedObject var model: ImageModel
    let attachment: ImageAttachment
    @ObservedObject var editor: EditorController

    @State private var image: NSImage?
    @State private var failed = false

    /// 圖片在文件裡的最大顯示尺寸；超過就等比例縮小。
    private static let maxSize = CGSize(width: 560, height: 640)

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay { BlockSelectionRing(editor: editor, id: ObjectIdentifier(attachment)) }
            .contentShape(Rectangle())
            .onTapGesture { editor.selectBlock(attachment) }
            .contextMenu {
                if editor.isEditable {
                    Button(String(localized: "刪除圖片", bundle: .module), role: .destructive) { editor.deleteBlock(attachment) }
                }
            }
            .task(id: editor.imageURL(for: model.path)) { await load() }
            // 區塊的高度由文字排版決定；圖片載入後要請它重新量一次。
            .onChange(of: image) { requestRelayout() }
            .onChange(of: failed) { requestRelayout() }
            .onChange(of: editor.blockWidth) { requestRelayout() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.alt.isEmpty ? String(localized: "圖片", bundle: .module) : String(localized: "圖片：\(model.alt)", bundle: .module))
    }

    @ViewBuilder
    private var content: some View {
        if let image, image.size.width > 0, image.size.height > 0 {
            // 明確給定顯示尺寸：文字排版量到的高度和實際畫出來的才會一致。
            let scale = min(1, min(Self.maxSize.width, editor.blockWidth) / image.size.width, Self.maxSize.height / image.size.height)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: image.size.width * scale)
                .frame(height: image.size.height * scale)
        } else if failed {
            VStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(Color.okmTextMuted)
                Text("找不到圖片「\(model.fileName)」", bundle: .module)
                    .foregroundStyle(Color.okmText)
                Text("圖片應該放在文件旁邊的「\(ImageStore.folderName)」資料夾裡。", bundle: .module)
                    .font(.callout)
                    .foregroundStyle(Color.okmTextMuted)
            }
            .frame(height: 110)
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(height: 110)
        }
    }

    private func requestRelayout() {
        DispatchQueue.main.async { editor.relayoutBlock(attachment) }
    }

    private func load() async {
        guard let url = editor.imageURL(for: model.path) else {
            image = nil
            failed = true
            return
        }
        let loaded: NSImage?
        if url.isFileURL {
            // 文件可能在網路磁碟上：讀檔放到背景。
            loaded = await Task.detached { NSImage(contentsOf: url) }.value
        } else {
            let data = try? await URLSession.shared.data(from: url).0
            loaded = data.flatMap(NSImage.init(data:))
        }
        guard !Task.isCancelled else { return }
        image = loaded
        failed = loaded == nil
    }
}
