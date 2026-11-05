import Carbon.HIToolbox
import CoreGraphics

/// A window placement command. The raw value is the suffix after `window.` in
/// `config.json`, so `window.left` configures `.left`.
enum WindowAction: String, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case maximize
    case center

    private static let controlOption = UInt32(controlKey | optionKey)

    private static func shortcut(
        _ keyCode: Int,
        _ name: String,
        _ equivalent: String
    ) -> HotKey {
        HotKey(
            keyCode: UInt32(keyCode),
            modifiers: controlOption,
            keyEquivalent: equivalent,
            keyName: name
        )
    }

    private static let leftShortcut = shortcut(kVK_LeftArrow, "←", "\u{F702}")
    private static let rightShortcut = shortcut(kVK_RightArrow, "→", "\u{F703}")
    private static let topShortcut = shortcut(kVK_UpArrow, "↑", "\u{F700}")
    private static let bottomShortcut = shortcut(kVK_DownArrow, "↓", "\u{F701}")
    private static let maximizeShortcut = shortcut(kVK_Return, "Return", "\r")
    private static let centerShortcut = shortcut(kVK_ANSI_C, "C", "c")

    /// Shortcut used when `config.json` omits the action. Quarter actions are
    /// available from the Window menu and can be bound, but ship unbound so
    /// the default keymap stays small.
    var defaultShortcut: HotKey? {
        switch self {
        case .left: Self.leftShortcut
        case .right: Self.rightShortcut
        case .top: Self.topShortcut
        case .bottom: Self.bottomShortcut
        case .maximize: Self.maximizeShortcut
        case .center: Self.centerShortcut
        case .topLeft, .topRight, .bottomLeft, .bottomRight: nil
        }
    }

    var title: String {
        switch self {
        case .left: "Left Half"
        case .right: "Right Half"
        case .top: "Top Half"
        case .bottom: "Bottom Half"
        case .topLeft: "Top Left Quarter"
        case .topRight: "Top Right Quarter"
        case .bottomLeft: "Bottom Left Quarter"
        case .bottomRight: "Bottom Right Quarter"
        case .maximize: "Maximize"
        case .center: "Center"
        }
    }

    /// Target frame in AppKit screen coordinates (origin bottom-left).
    ///
    /// Halves and quarters tile `visible` exactly. Center preserves the
    /// current size unless the window is larger than the screen, in which case
    /// it fills the available space.
    func frame(current: CGRect, visible: CGRect) -> CGRect {
        let halfWidth = visible.width / 2
        let halfHeight = visible.height / 2

        switch self {
        case .left:
            return CGRect(
                x: visible.minX,
                y: visible.minY,
                width: halfWidth,
                height: visible.height
            )
        case .right:
            return CGRect(
                x: visible.midX,
                y: visible.minY,
                width: halfWidth,
                height: visible.height
            )
        case .top:
            return CGRect(
                x: visible.minX,
                y: visible.midY,
                width: visible.width,
                height: halfHeight
            )
        case .bottom:
            return CGRect(
                x: visible.minX,
                y: visible.minY,
                width: visible.width,
                height: halfHeight
            )
        case .topLeft:
            return CGRect(
                x: visible.minX,
                y: visible.midY,
                width: halfWidth,
                height: halfHeight
            )
        case .topRight:
            return CGRect(
                x: visible.midX,
                y: visible.midY,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomLeft:
            return CGRect(
                x: visible.minX,
                y: visible.minY,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomRight:
            return CGRect(
                x: visible.midX,
                y: visible.minY,
                width: halfWidth,
                height: halfHeight
            )
        case .maximize:
            return visible
        case .center:
            let width = min(current.width, visible.width)
            let height = min(current.height, visible.height)
            return CGRect(
                x: visible.midX - width / 2,
                y: visible.midY - height / 2,
                width: width,
                height: height
            )
        }
    }

    /// Index of the screen holding the largest part of `window`. Windows that
    /// are entirely off-screen fall back to `fallback`.
    static func targetScreenIndex(
        for window: CGRect,
        in screens: [CGRect],
        fallback: Int = 0
    ) -> Int {
        guard !screens.isEmpty else { return fallback }

        var bestIndex = fallback
        var bestArea: CGFloat = 0

        for (index, screen) in screens.enumerated() {
            let intersection = window.intersection(screen)
            let area = intersection.isNull
                ? 0
                : intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                bestIndex = index
            }
        }

        guard bestArea > 0 else {
            return min(max(fallback, 0), screens.count - 1)
        }
        return bestIndex
    }
}
