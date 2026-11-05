import AppKit
import ApplicationServices

/// Converts between AppKit's bottom-left screen space and the Accessibility
/// API's top-left space. Both share the primary display's width in points, so
/// flipping around the primary display's height is enough.
enum WindowCoordinates {
    static func toAX(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func fromAX(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        toAX(rect, primaryHeight: primaryHeight)
    }
}

/// Moves and resizes the focused window of another app through the
/// Accessibility API. Accessibility is already required for snippet pasting
/// and inline expansion; this reuses that grant.
@MainActor
final class WindowManager {
    /// Called when a window command is blocked because Accessibility is not
    /// granted, so the owner can send the user to the permission wizard.
    var onAccessibilityMissing: (() -> Void)?

    func perform(_ action: WindowAction, on application: NSRunningApplication) {
        guard AXIsProcessTrusted() else {
            NSLog(
                "Heycast: window %@: Accessibility is required",
                action.rawValue
            )
            onAccessibilityMissing?()
            return
        }

        guard !application.isTerminated else {
            NSLog(
                "Heycast: window %@: %@ is not running",
                action.rawValue,
                application.localizedName ?? "app"
            )
            return
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = focusedWindow(of: appElement) else {
            NSLog(
                "Heycast: window %@: %@ has no focused window",
                action.rawValue,
                application.localizedName ?? "app"
            )
            return
        }

        guard let axFrame = frame(of: window) else {
            NSLog("Heycast: window %@: cannot read the window frame", action.rawValue)
            return
        }

        let screens = NSScreen.screens
        guard let primary = screens.first else { return }
        let primaryHeight = primary.frame.height
        let current = WindowCoordinates.fromAX(axFrame, primaryHeight: primaryHeight)
        let index = WindowAction.targetScreenIndex(
            for: current,
            in: screens.map(\.frame)
        )
        guard screens.indices.contains(index) else { return }

        let target = action.frame(
            current: current,
            visible: screens[index].visibleFrame
        )
        set(
            WindowCoordinates.toAX(target, primaryHeight: primaryHeight),
            on: window,
            action: action
        )
    }

    private func focusedWindow(of application: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute, of: window),
              let size = sizeAttribute(kAXSizeAttribute, of: window)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func pointAttribute(
        _ attribute: String,
        of window: AXUIElement
    ) -> CGPoint? {
        guard let value = valueAttribute(attribute, of: window) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeAttribute(
        _ attribute: String,
        of window: AXUIElement
    ) -> CGSize? {
        guard let value = valueAttribute(attribute, of: window) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private func valueAttribute(
        _ attribute: String,
        of window: AXUIElement
    ) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window,
            attribute as CFString,
            &value
        ) == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        return (value as! AXValue)
    }

    /// Move before resizing: the window server clamps a resize that would
    /// overflow the screen at the old origin. Setting the position again after
    /// the resize corrects a first move that was clamped by the old size.
    private func set(
        _ frame: CGRect,
        on window: AXUIElement,
        action: WindowAction
    ) {
        setPosition(frame.origin, on: window, action: action)
        setSize(frame.size, on: window, action: action)
        setPosition(frame.origin, on: window, action: action)
    }

    private func setPosition(
        _ position: CGPoint,
        on window: AXUIElement,
        action: WindowAction
    ) {
        var origin = position
        guard let originValue = AXValueCreate(.cgPoint, &origin) else { return }
        let result = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            originValue
        )
        if result != .success {
            NSLog(
                "Heycast: window %@: cannot move (%d)",
                action.rawValue,
                result.rawValue
            )
        }
    }

    private func setSize(
        _ size: CGSize,
        on window: AXUIElement,
        action: WindowAction
    ) {
        var size = size
        guard let sizeValue = AXValueCreate(.cgSize, &size) else { return }
        let result = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        if result != .success {
            NSLog(
                "Heycast: window %@: cannot resize (%d)",
                action.rawValue,
                result.rawValue
            )
        }
    }
}
