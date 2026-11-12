// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import PDFKit
import SwiftUI

struct PrintPreviewItem: Identifiable {
    let id = UUID()
    /// 暫存的 PDF；內容和「轉成 PDF」存出來的完全相同。
    let url: URL
}

/// 預覽列印：把分頁後的結果一次攤開來看，確認沒問題再列印或存檔。
struct PrintPreviewSheet: View {
    let item: PrintPreviewItem
    let onPrint: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    private enum PageLayout: String, CaseIterable {
        case single, double, grid

        var title: String {
            switch self {
            case .single: String(localized: "單頁", bundle: .module)
            case .double: String(localized: "雙頁", bundle: .module)
            case .grid: String(localized: "多頁", bundle: .module)
            }
        }
    }

    @State private var layout: PageLayout = .grid
    @State private var document: PDFDocument?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("預覽列印", bundle: .module)
                    .font(.title3.weight(.semibold))
                if let document {
                    Text("共 \(document.pageCount) 頁", bundle: .module)
                        .foregroundStyle(Color.okmTextMuted)
                        .monospacedDigit()
                }
                Spacer()
                Picker(String(localized: "排列方式", bundle: .module), selection: $layout) {
                    ForEach(PageLayout.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            Group {
                if let document {
                    switch layout {
                    case .grid:
                        PageGrid(document: document)
                    case .single, .double:
                        PDFPages(document: document, twoUp: layout == .double)
                    }
                } else {
                    Text("無法顯示預覽。請關閉後再試一次。", bundle: .module)
                        .foregroundStyle(Color.okmTextMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.okmSurfaceSunken)

            Divider()

            HStack {
                Button(String(localized: "關閉", bundle: .module), role: .cancel, action: onClose)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(String(localized: "存成 PDF…", bundle: .module), action: onSave)
                Button(String(localized: "列印…", bundle: .module), action: onPrint)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.okmPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 980, height: 740)
        .onAppear { document = PDFDocument(url: item.url) }
    }
}

/// 所有頁面縮小排成格子，一眼看完整份文件的分頁。
private struct PageGrid: View {
    let document: PDFDocument

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 24)], spacing: 24) {
                ForEach(0..<document.pageCount, id: \.self) { index in
                    VStack(spacing: 8) {
                        if let page = document.page(at: index) {
                            Image(nsImage: page.thumbnail(of: CGSize(width: 480, height: 680), for: .mediaBox))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                                .accessibilityLabel(String(localized: "第 \(index + 1) 頁", bundle: .module))
                        }
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(Color.okmTextMuted)
                            .monospacedDigit()
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(28)
        }
    }
}

private struct PDFPages: NSViewRepresentable {
    let document: PDFDocument
    let twoUp: Bool

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displaysPageBreaks = true
        view.backgroundColor = .clear
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
        view.displayMode = twoUp ? .twoUpContinuous : .singlePageContinuous
        view.autoScales = true
    }
}
