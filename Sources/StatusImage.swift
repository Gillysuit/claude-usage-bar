import AppKit

/// Glow dot plus two stacked rows ("Session 9%" over "Weekly 4%"), drawn as one image for the status item.
/// Uses dynamic label colors, which resolve against the menu bar's appearance each time it draws.
enum StatusImage {
    private static let height: CGFloat = 22
    private static let dotSize: CGFloat = 8
    private static let labelFont = NSFont.systemFont(ofSize: 9.5, weight: .medium)
    private static let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .semibold)

    static func make(color: NSColor, session: Double?, weekly: Double?) -> NSImage {
        let rows = [("Session", session), ("Weekly", weekly)].compactMap { label, value in
            value.map { (label, "\(Int($0.rounded()))%") }
        }
        let labelWidth = rows.map { width($0.0, labelFont) }.max() ?? 0
        let valueWidth = rows.map { width($0.1, valueFont) }.max() ?? 0
        let textX = 4 + dotSize + 6
        let valueRight = textX + labelWidth + 4 + valueWidth
        let size = NSSize(width: rows.isEmpty ? dotSize + 8 : valueRight + 1, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            drawDot(color)
            let lineHeight = height / 2
            for (i, row) in rows.enumerated() {
                // Top row sits in the upper half; a lone row is centered.
                let y = rows.count == 1 ? lineHeight / 2 - 0.5 : (i == 0 ? lineHeight - 0.5 : -0.5)
                draw(row.0, labelFont, .secondaryLabelColor, x: textX, y: y)
                draw(row.1, valueFont, .labelColor, x: valueRight - width(row.1, valueFont), y: y)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawDot(_ color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = .zero
        shadow.set()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 4, y: (height - dotSize) / 2, width: dotSize, height: dotSize)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func width(_ text: String, _ font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func draw(_ text: String, _ font: NSFont, _ color: NSColor, x: CGFloat, y: CGFloat) {
        (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
    }
}
