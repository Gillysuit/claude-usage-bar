import AppKit

/// Two stacked rows ("Session 9%" over "Weekly 4%") for the status item, with room on the left for GlowDotView.
/// Uses dynamic label colors, which resolve against the menu bar's appearance each time it draws.
enum StatusImage {
    /// Leading space left empty for the animated dot.
    static let dotSpace = GlowDotView.size
    private static let height: CGFloat = 22
    private static let labelFont = NSFont.systemFont(ofSize: 9.5, weight: .medium)
    private static let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .semibold)

    static func make(session: Double?, weekly: Double?) -> NSImage {
        let rows = [("Session", session), ("Weekly", weekly)].compactMap { label, value in
            value.map { (label, "\(Int($0.rounded()))%") }
        }
        let labelWidth = rows.map { width($0.0, labelFont) }.max() ?? 0
        let valueWidth = rows.map { width($0.1, valueFont) }.max() ?? 0
        let textX = dotSpace + 2
        let valueRight = textX + labelWidth + 4 + valueWidth
        let size = NSSize(width: rows.isEmpty ? dotSpace : valueRight + 1, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
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

    private static func width(_ text: String, _ font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func draw(_ text: String, _ font: NSFont, _ color: NSColor, x: CGFloat, y: CGFloat) {
        (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
    }
}
