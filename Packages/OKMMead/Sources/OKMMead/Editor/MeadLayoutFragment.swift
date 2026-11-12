// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OKMaster Inc.
import AppKit

/// 在段落文字之外多畫一層裝飾：清單記號、待辦方框、引言的細線、程式碼區塊的底色。
/// 這些都不是文字內容，所以不會被選取、複製，也不會存進檔案。
final class MeadLayoutFragment: NSTextLayoutFragment {
    enum Decoration {
        case none
        case marker(String)
        case checkbox(Bool)
        case quote
        case code(isFirst: Bool, isLast: Bool)
    }

    var decoration: Decoration = .none
    var markerFont: NSFont = .systemFont(ofSize: 15)
    /// 文件以換行結尾時，最後那個空行沒有自己的段落，TextKit 把它併進上一段的片段裡。
    /// 那一行的清單記號要由上一段的片段代畫，否則新項目要等打了字才看得到圓點或方框。
    var trailingDecoration: Decoration = .none
    var trailingMarkerFont: NSFont = .systemFont(ofSize: 15)

    /// 併進這個片段的結尾空行（如果有）。
    var trailingEmptyLine: NSTextLineFragment? {
        guard textLineFragments.count > 1, let last = textLineFragments.last, last.characterRange.length == 0 else { return nil }
        return last
    }

    static let markerGap: CGFloat = 8
    static let checkboxSize: CGFloat = 14

    private var containerWidth: CGFloat {
        textLayoutManager?.textContainer?.size.width ?? layoutFragmentFrame.width
    }

    override var renderingSurfaceBounds: CGRect {
        let base = super.renderingSurfaceBounds
        let full = CGRect(x: -layoutFragmentFrame.minX, y: 0, width: containerWidth, height: layoutFragmentFrame.height)
        return base.union(full)
    }

    /// 待辦方框在段落座標系中的位置，供點擊判斷使用。
    var checkboxRect: CGRect? {
        guard case .checkbox = decoration, let line = textLineFragments.first else { return nil }
        return Self.checkboxRect(for: line)
    }

    private static func checkboxRect(for line: NSTextLineFragment) -> CGRect {
        let size = checkboxSize
        let lineBounds = line.typographicBounds
        // 以字身的中心（基線往上半個大寫高度）為準；行框含行距，用它的中心會讓方框偏高。
        let capHeight = Theme.font(for: .body, bold: false, italic: false, inlineCode: false).capHeight
        let center = lineBounds.minY + line.glyphOrigin.y - capHeight / 2
        return CGRect(x: lineBounds.minX - size - markerGap, y: center - size / 2, width: size, height: size)
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.current = previous }

        if let line = textLineFragments.first {
            drawListMark(decoration, font: markerFont, line: line, at: point)
        }
        if let line = trailingEmptyLine {
            drawListMark(trailingDecoration, font: trailingMarkerFont, line: line, at: point)
        }

        switch decoration {
        case .none, .marker, .checkbox:
            break
        case .quote:
            let rule = CGRect(x: point.x - layoutFragmentFrame.minX + 6, y: point.y, width: 1, height: layoutFragmentFrame.height)
            Palette.borderStrong.setFill()
            rule.fill()
        case .code(let isFirst, let isLast):
            let rect = CGRect(x: point.x - layoutFragmentFrame.minX, y: point.y, width: containerWidth, height: layoutFragmentFrame.height)
            let radius: CGFloat = 6
            let path = NSBezierPath()
            let top = isFirst ? radius : 0
            let bottom = isLast ? radius : 0
            path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
            path.line(to: CGPoint(x: rect.maxX - top, y: rect.minY))
            if top > 0 { path.appendArc(from: CGPoint(x: rect.maxX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.minY + top), radius: top) }
            path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
            if bottom > 0 { path.appendArc(from: CGPoint(x: rect.maxX, y: rect.maxY), to: CGPoint(x: rect.maxX - bottom, y: rect.maxY), radius: bottom) }
            path.line(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
            if bottom > 0 { path.appendArc(from: CGPoint(x: rect.minX, y: rect.maxY), to: CGPoint(x: rect.minX, y: rect.maxY - bottom), radius: bottom) }
            path.line(to: CGPoint(x: rect.minX, y: rect.minY + top))
            if top > 0 { path.appendArc(from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.minX + top, y: rect.minY), radius: top) }
            path.close()
            Theme.pageSunken.setFill()
            path.fill()
        }

        super.draw(at: point, in: context)
    }

    private func drawListMark(_ mark: Decoration, font: NSFont, line: NSTextLineFragment, at point: CGPoint) {
        switch mark {
        case .marker(let text):
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Palette.textMuted]
            let marker = NSAttributedString(string: text, attributes: attributes)
            let size = marker.size()
            let baseline = point.y + line.typographicBounds.minY + line.glyphOrigin.y
            marker.draw(at: CGPoint(
                x: point.x + line.typographicBounds.minX - size.width - Self.markerGap,
                y: baseline - font.ascender
            ))
        case .checkbox(let checked):
            let rect = Self.checkboxRect(for: line).offsetBy(dx: point.x, dy: point.y)
            let box = NSBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), xRadius: 3.5, yRadius: 3.5)
            if checked {
                Palette.primary.setFill()
                box.fill()
                let tick = NSBezierPath()
                tick.move(to: CGPoint(x: rect.minX + 3.5, y: rect.midY + 0.5))
                tick.line(to: CGPoint(x: rect.minX + 6, y: rect.maxY - 4))
                tick.line(to: CGPoint(x: rect.maxX - 3.5, y: rect.minY + 4.5))
                tick.lineWidth = 1.6
                tick.lineCapStyle = .round
                tick.lineJoinStyle = .round
                Palette.onPrimary.setStroke()
                tick.stroke()
            } else {
                Palette.borderStrong.setStroke()
                box.lineWidth = 1.5
                box.stroke()
            }
        default:
            break
        }
    }
}
