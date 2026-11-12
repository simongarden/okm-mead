import AppKit
import SwiftUI

/// 動態 Logo：小方塊在散落位置淡入，各自飛回原位拼成 M。
/// 圖形與時間軸取自 `Resources/launch-logo.svg`（設計稿以 CSS 動畫撰寫），這裡改用圖層動畫重現，
/// 不必為一個標誌啟動網頁檢視。系統開啟「減少動態效果」時直接顯示完整 Logo。
final class LaunchLogoView: NSView {
    /// 動畫真正開始時呼叫（檢視進入視窗之後），讓產品名稱的淡入從同一刻起算。
    var onPlay: (@MainActor () -> Void)?

    /// 整段動畫的長度（秒）：最後一塊抵達後，完整 Logo 疊上淡入結束的時間。
    static let duration: CFTimeInterval = 1.76

    private static let viewBox: CGFloat = 1024
    private let stage = CALayer()

    /// SVG 的 y 軸向下；檢視也用向下的座標，圖層內容就不必另外反轉。
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        stage.bounds = CGRect(x: 0, y: 0, width: Self.viewBox, height: Self.viewBox)
        layer?.addSublayer(stage)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("不支援從 nib 建立") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = min(bounds.width, bounds.height)
        stage.position = CGPoint(x: bounds.midX, y: bounds.midY)
        stage.setAffineTransform(CGAffineTransform(scaleX: side / Self.viewBox, y: side / Self.viewBox))
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        play()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        guard window != nil else { return }
        build(animated: false)
    }

    func play() {
        build(animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        onPlay?()
    }

    private func build(animated: Bool) {
        stage.sublayers = nil
        let artwork = LaunchLogoArtwork.shared
        let now = stage.convertTime(CACurrentMediaTime(), from: nil)
        let full = stage.bounds

        let base = CAShapeLayer()
        base.frame = full
        base.path = CGPath(ellipseIn: full, transform: nil)
        base.fillColor = OKMPalette.brandNavy.cgColor
        stage.addSublayer(base)

        let bits = CALayer()
        bits.frame = full
        let disc = CAShapeLayer()
        disc.frame = full
        disc.path = base.path
        bits.mask = disc
        stage.addSublayer(bits)

        let solid = CALayer()
        solid.frame = full
        for shape in artwork.solid {
            let layer = CAShapeLayer()
            layer.frame = full
            layer.path = shape.path
            layer.fillColor = color(shape.isWhite)
            solid.addSublayer(layer)
        }
        stage.addSublayer(solid)

        guard animated else { return }

        let baseIn = CAAnimationGroup()
        baseIn.animations = [
            basic("opacity", from: 0, to: 1),
            basic("transform.scale", from: 0.82, to: 1),
        ]
        baseIn.duration = 0.342
        baseIn.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.15)
        base.add(baseIn, forKey: "in")

        for bit in artwork.bits {
            let box = bit.path.boundingBoxOfPath
            var toOrigin = CGAffineTransform(translationX: -box.minX, y: -box.minY)
            let layer = CAShapeLayer()
            layer.frame = box
            layer.path = bit.path.copy(using: &toOrigin)
            layer.fillColor = color(bit.isWhite)
            layer.strokeColor = layer.fillColor
            layer.lineWidth = 1
            layer.lineJoin = .round
            bits.addSublayer(layer)

            let scattered = CATransform3DScale(CATransform3DMakeTranslation(bit.offset.x, bit.offset.y, 0), bit.scale, bit.scale, 1)
            let move = CAKeyframeAnimation(keyPath: "transform")
            move.values = [scattered, scattered, CATransform3DIdentity].map { NSValue(caTransform3D: $0) }
            move.keyTimes = [0, 0.16, 1]
            move.timingFunctions = [CAMediaTimingFunction(name: .linear), CAMediaTimingFunction(controlPoints: 0.55, 0, 0.2, 1)]
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1]
            fade.keyTimes = [0, 0.16, 1]
            fade.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .linear)]
            let gather = CAAnimationGroup()
            gather.animations = [move, fade]
            gather.duration = 0.75
            gather.beginTime = now + bit.delay
            gather.fillMode = .backwards
            layer.add(gather, forKey: "gather")
        }

        // 完整 Logo 最後疊上，蓋掉小方塊之間的接縫。
        let solidIn = basic("opacity", from: 0, to: 1)
        solidIn.duration = 0.16
        solidIn.beginTime = now + 1.6
        solidIn.fillMode = .backwards
        solid.add(solidIn, forKey: "in")
    }

    private func basic(_ keyPath: String, from: CGFloat, to: CGFloat) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        return animation
    }

    private func color(_ isWhite: Bool) -> CGColor {
        isWhite ? NSColor.white.cgColor : OKMPalette.brandSlate.cgColor
    }
}

/// 從 `launch-logo.svg` 讀出的圖形：完整 Logo 的多邊形，以及每個小方塊的散落位移、縮放與出場時間。
@MainActor
private struct LaunchLogoArtwork {
    struct Bit {
        let path: CGPath
        let isWhite: Bool
        let offset: CGPoint
        let scale: CGFloat
        let delay: CFTimeInterval
    }

    struct Shape {
        let path: CGPath
        let isWhite: Bool
    }

    var bits: [Bit] = []
    var solid: [Shape] = []

    static let shared = LaunchLogoArtwork()

    private init() {
        guard let url = Bundle.main.url(forResource: "launch-logo", withExtension: "svg"),
              let svg = try? String(contentsOf: url, encoding: .utf8) else { return }
        let number = #"(-?[\d.]+)"#
        let bitPattern = #"<polygon class="b (gray|white)" style="--x:"# + number + #"px;--y:"# + number
            + #"px;--s:"# + number + #";animation-delay:"# + number + #"ms" points="([^"]+)""#
        for match in Self.matches(bitPattern, in: svg) {
            guard let x = Double(match[2]), let y = Double(match[3]), let scale = Double(match[4]),
                  let delay = Double(match[5]), let path = Self.polygon(match[6]) else { continue }
            bits.append(Bit(path: path, isWhite: match[1] == "white", offset: CGPoint(x: x, y: y),
                            scale: scale, delay: delay / 1000))
        }
        for match in Self.matches(#"<polygon class="(gray|white)" points="([^"]+)""#, in: svg) {
            guard let path = Self.polygon(match[2]) else { continue }
            solid.append(Shape(path: path, isWhite: match[1] == "white"))
        }
    }

    private static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: source.length)).map { result in
            (0..<result.numberOfRanges).map { source.substring(with: result.range(at: $0)) }
        }
    }

    private static func polygon(_ points: String) -> CGPath? {
        let values = points.split(separator: " ").compactMap { Double($0) }
        guard values.count >= 6, values.count.isMultiple(of: 2) else { return nil }
        let path = CGMutablePath()
        for index in stride(from: 0, to: values.count, by: 2) {
            let point = CGPoint(x: values[index], y: values[index + 1])
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct LaunchLogo: NSViewRepresentable {
    var onPlay: (@MainActor () -> Void)?

    func makeNSView(context: Context) -> LaunchLogoView {
        let view = LaunchLogoView(frame: .zero)
        view.onPlay = onPlay
        return view
    }

    func updateNSView(_ view: LaunchLogoView, context: Context) {}
}
