// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit
import SwiftUI

/// 流程圖的內容（Mermaid 文字）。
@MainActor
final class DiagramModel: ObservableObject {
    @Published private(set) var source: String
    var onChange: ((_ before: String) -> Void)?

    init(source: String) {
        self.source = source
    }

    func update(_ newSource: String) {
        guard newSource != source else { return }
        let before = source
        source = newSource
        onChange?(before)
    }
}

/// 佔一整個段落的區塊（表格、流程圖、分隔線）。
/// 重新排版時 TextKit 會再要一次 view provider；回傳同一個，才不會讓正在輸入的儲存格失去焦點。
@MainActor
class BlockAttachment: NSTextAttachment {
    private var cachedProvider: BlockViewProvider?

    init() {
        super.init(data: nil, ofType: nil)
        allowsTextAttachmentView = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BlockAttachment 不支援封存")
    }

    func makeHostingController(editor: EditorController?) -> NSViewController {
        fatalError("子類別必須覆寫")
    }

    override nonisolated func viewProvider(
        for parentView: NSView?, location: any NSTextLocation, textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        // 回傳值不是 Sendable，不能直接從 assumeIsolated 帶出來。
        // TextKit 只在主執行緒排版，但這些型別沒有並行標註。
        nonisolated(unsafe) var result: NSTextAttachmentViewProvider?
        nonisolated(unsafe) let attachment = self
        nonisolated(unsafe) let location = location
        nonisolated(unsafe) let textContainer = textContainer
        MainActor.assumeIsolated {
            if let cachedProvider = attachment.cachedProvider, cachedProvider.parentView === parentView {
                result = cachedProvider
                return
            }
            let provider = BlockViewProvider(
                textAttachment: attachment, parentView: parentView,
                textLayoutManager: textContainer?.textLayoutManager, location: location
            )
            provider.tracksTextAttachmentViewBounds = true
            attachment.cachedProvider = provider
            result = provider
        }
        return result
    }
}

final class BlockViewProvider: NSTextAttachmentViewProvider {
    private var controller: NSViewController?
    weak var parentView: NSView?

    override init(
        textAttachment: NSTextAttachment, parentView: NSView?,
        textLayoutManager: NSTextLayoutManager?, location: any NSTextLocation
    ) {
        self.parentView = parentView
        super.init(textAttachment: textAttachment, parentView: parentView,
                   textLayoutManager: textLayoutManager, location: location)
    }

    override func loadView() {
        nonisolated(unsafe) let provider = self
        MainActor.assumeIsolated {
            provider.view = provider.hostingController().view
        }
    }

    @MainActor
    private func hostingController() -> NSViewController {
        if let controller { return controller }
        let editor = (parentView as? MeadTextView)?.editor
        let created = (textAttachment as? BlockAttachment)?.makeHostingController(editor: editor) ?? NSViewController()
        controller = created
        return created
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any], location: any NSTextLocation,
        textContainer: NSTextContainer?, proposedLineFragment: CGRect, position: CGPoint
    ) -> CGRect {
        nonisolated(unsafe) let provider = self
        return MainActor.assumeIsolated {
            let width = max(proposedLineFragment.width, 120)
            (provider.hostingController() as? DiagramHostingController)?.prepare(forWidth: width)
            guard let hosting = provider.hostingController() as? BlockHosting else {
                return CGRect(x: 0, y: 0, width: width, height: 24)
            }
            return CGRect(x: 0, y: 0, width: width, height: ceil(hosting.height(forWidth: width)))
        }
    }
}

@MainActor
protocol BlockHosting {
    func height(forWidth width: CGFloat) -> CGFloat
}

extension NSHostingController: BlockHosting {
    func height(forWidth width: CGFloat) -> CGFloat {
        sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
}

/// 流程圖要知道文字欄有多寬才能等比例縮小，量尺寸時把寬度帶進內容再量。
final class DiagramHostingController: NSHostingController<DiagramBlockView> {
    func prepare(forWidth width: CGFloat) {
        if abs(rootView.availableWidth - width) > 0.5 { rootView.availableWidth = width }
    }
}

final class TableAttachment: BlockAttachment {
    let model: TableModel

    init(model: TableModel) {
        self.model = model
        super.init()
    }

    override func makeHostingController(editor: EditorController?) -> NSViewController {
        model.onChange = { [weak self, weak editor] before in
            guard let self else { return }
            editor?.blockDidChange(self, actionName: String(localized: "編輯表格", bundle: .module)) { self.model.restore(before) }
        }
        return NSHostingController(rootView: TableBlockView(model: model, attachment: self, editor: editor))
    }
}

final class DiagramAttachment: BlockAttachment {
    let model: DiagramModel

    init(model: DiagramModel) {
        self.model = model
        super.init()
    }

    override func makeHostingController(editor: EditorController?) -> NSViewController {
        model.onChange = { [weak self, weak editor] before in
            guard let self else { return }
            editor?.blockDidChange(self, actionName: String(localized: "編輯流程圖", bundle: .module)) { self.model.update(before) }
        }
        return DiagramHostingController(rootView: DiagramBlockView(model: model, attachment: self, editor: editor))
    }
}

/// 圖片的說明文字與路徑（Markdown 的 `![說明](路徑)`）。
@MainActor
final class ImageModel: ObservableObject {
    @Published var alt: String
    @Published var path: String

    init(alt: String, path: String) {
        self.alt = alt
        self.path = path
    }

    var fileName: String {
        ((path.removingPercentEncoding ?? path) as NSString).lastPathComponent
    }
}

final class ImageAttachment: BlockAttachment {
    let model: ImageModel

    init(model: ImageModel) {
        self.model = model
        super.init()
    }

    override func makeHostingController(editor: EditorController?) -> NSViewController {
        guard let editor else { return NSViewController() }
        return NSHostingController(rootView: ImageBlockView(model: model, attachment: self, editor: editor))
    }
}

final class DividerAttachment: BlockAttachment {
    override func makeHostingController(editor: EditorController?) -> NSViewController {
        NSHostingController(rootView: DividerBlockView())
    }
}

struct DividerBlockView: View {
    var body: some View {
        Rectangle()
            .fill(Color.okmBorder)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .accessibilityLabel(String(localized: "分隔線", bundle: .module))
    }
}
