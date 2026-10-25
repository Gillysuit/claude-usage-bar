import AppKit
import QuartzCore

/// Lava-lamp dot for the status item: two colors swirl inside the dot while its glow breathes between them.
/// Kept cheap for the window server: glows are blurred once into images and only faded,
/// and animations are capped at a low frame rate. Static when Reduce Motion is on.
final class GlowDotView: NSView {
    static let size: CGFloat = 16
    private static let dotSize: CGFloat = 8
    private static let frameRate = CAFrameRateRange(minimum: 8, maximum: 15, preferred: 12)

    private let glowGroup = CALayer()
    private let glowA = CALayer()
    private let glowB = CALayer()
    private let core = CALayer()
    private let swirl = CAGradientLayer()
    private var level: UsageLevel?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let d = Self.dotSize
        let bounds = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)
        glowGroup.frame = bounds
        for glow in [glowA, glowB] {
            glow.frame = bounds
            glow.contentsGravity = .resizeAspect
            glowGroup.addSublayer(glow)
        }

        core.frame = CGRect(x: (Self.size - d) / 2, y: (Self.size - d) / 2, width: d, height: d)
        core.cornerRadius = d / 2
        core.masksToBounds = true
        // Just big enough (d·√2) that the rotating square always covers the round dot, so both colors stay visible.
        let pad = d * (2.squareRoot() - 1) / 2
        swirl.frame = core.bounds.insetBy(dx: -pad, dy: -pad)
        swirl.startPoint = CGPoint(x: 0, y: 0)
        swirl.endPoint = CGPoint(x: 1, y: 1)
        core.addSublayer(swirl)

        layer?.addSublayer(glowGroup)
        layer?.addSublayer(core)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Let clicks fall through to the status bar button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func setLevel(_ newLevel: UsageLevel) {
        // Only restart the animation when the level actually changes, not on every refresh.
        guard newLevel != level else { return }
        level = newLevel
        let (a, b) = newLevel.colors
        [glowGroup, glowB, swirl].forEach { $0.removeAllAnimations() }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        for (glow, color) in [(glowA, a), (glowB, b)] {
            glow.contentsScale = scale
            glow.contents = Self.glowImage(color).layerContents(forContentsScale: scale)
        }
        glowB.opacity = 0
        swirl.colors = [a.cgColor, b.cgColor]

        guard newLevel != .unknown, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        // Slow and calm normally; quicker near the limit.
        let period: CFTimeInterval = newLevel == .high ? 2.5 : 5

        // Glow color drifts a→b while its brightness breathes on a slightly offset beat.
        glowB.add(breathing("opacity", from: 0, to: 1, period: period), forKey: "fade")
        glowGroup.add(breathing("opacity", from: 0.55, to: 1, period: period * 0.7), forKey: "pulse")

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = period * 2
        spin.repeatCount = .infinity
        spin.preferredFrameRateRange = Self.frameRate
        swirl.add(spin, forKey: "spin")
    }

    private func breathing(_ keyPath: String, from: Double, to: Double, period: CFTimeInterval) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = period
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.preferredFrameRateRange = Self.frameRate
        return animation
    }

    /// A dot with its soft glow, blurred once here instead of on every animation frame.
    private static func glowImage(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let shadow = NSShadow()
            shadow.shadowColor = color
            shadow.shadowBlurRadius = 4
            shadow.shadowOffset = .zero
            shadow.set()
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: (size - dotSize) / 2, dy: (size - dotSize) / 2)).fill()
            return true
        }
    }
}
