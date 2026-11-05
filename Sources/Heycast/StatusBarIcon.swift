import AppKit

/// The status-bar mark: the app's H monogram drawn as a template image.
///
/// A template image carries alpha only, so AppKit tints it — black on a light
/// menu bar, white on a dark one — instead of drawing the colored app icon.
/// The geometry mirrors `Resources/AppIcon.svg` (two stems and a crossbar at
/// the same proportions) so the menu bar and Finder read as one mark.
enum StatusBarIcon {
    private static let height: CGFloat = 15
    private static let width = height * 360 / 470
    private static let stem = height * 96 / 470
    private static let bar = height * 70 / 470

    static let image: NSImage = {
        let canvas = NSSize(width: 16, height: 16)
        let x = (canvas.width - width) / 2
        let y = (canvas.height - height) / 2
        let image = NSImage(size: canvas, flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(rect: NSRect(x: x, y: y, width: stem, height: height)).fill()
            NSBezierPath(rect: NSRect(x: x + width - stem, y: y, width: stem, height: height)).fill()
            NSBezierPath(rect: NSRect(
                x: x + stem,
                y: y + (height - bar) / 2,
                width: width - 2 * stem,
                height: bar
            )).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Heycast"
        return image
    }()
}
