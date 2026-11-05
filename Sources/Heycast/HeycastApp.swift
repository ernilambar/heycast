import AppKit

/// Entry point for the accessory (status-bar-only) app.
///
/// Built as a SwiftPM executable and wrapped in a `.app` bundle by the
/// Makefile; `LSUIElement` in Info.plist keeps it out of the Dock.
@main
enum HeycastApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate

        // NSApplication.delegate is weak, so the delegate must outlive run().
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
