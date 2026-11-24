import AppKit

/// A short message near the bottom of the screen for failures that would
/// otherwise reach only the log: the palette closed or a shortcut did
/// nothing, and the user deserves to know why. It never takes focus or
/// clicks and hides on its own; details stay in the log.
@MainActor
enum Toast {
    private static var panel: NSPanel?
    private static var label: NSTextField?
    private static var dismissal: DispatchWorkItem?

    static func show(_ message: String) {
        let panel = panel ?? makePanel()
        label?.stringValue = message
        position(panel)
        panel.orderFrontRegardless()
        NSAccessibility.post(
            element: panel,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )

        dismissal?.cancel()
        let work = DispatchWorkItem {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
        dismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true

        let label = NSTextField(wrappingLabelWithString: "")
        label.font = .systemFont(ofSize: 13)
        label.alignment = .center
        label.maximumNumberOfLines = 3
        label.cell?.truncatesLastVisibleLine = true
        label.preferredMaxLayoutWidth = 420
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: background.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -10),
        ])
        panel.contentView = background

        self.panel = panel
        self.label = label
        return panel
    }

    private static func position(_ panel: NSPanel) {
        guard let label, let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return }
        let text = label.fittingSize
        let size = NSSize(width: ceil(text.width) + 32, height: ceil(text.height) + 20)
        let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 80)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
