import AppKit
import ApplicationServices

/// TCC state for a single privacy permission, collapsed to what the wizard
/// can display and act on.
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case restricted

    var isGranted: Bool { self == .granted }
}

/// The macOS permissions the wizard walks through.
///
/// Only grants a shipped or committed feature needs belong here. Today that is
/// Accessibility alone: snippets read the focused text and type the expansion
/// back in, and any future UI action needs the same grant.
///
/// Deliberately absent:
/// - Microphone / Speech Recognition: no audio code exists. Add them with the
///   voice feature, and Speech only if transcription uses Apple's recognizer.
/// - Input Monitoring: a keyword event tap that can modify events (the kind
///   snippets need to swallow the trigger) is authorized by Accessibility.
/// - Screen Recording / Full Disk Access: nothing reads the screen or
///   protected files; these are the two most invasive grants.
///
/// `openSettings` uses the classic `x-apple.systempreferences` anchor: it
/// survives the System Settings redesign, unlike the 13+ bundle identifiers.
enum Permission: String, CaseIterable, Identifiable {
    case accessibility

    var id: String { rawValue }

    // MARK: - Presentation

    var title: String { "Accessibility" }

    var summary: String {
        "heycast reads the focused window and types on your behalf, which is how snippets expand in place and how actions reach the app in front."
    }

    var instruction: String {
        "Turn heycast on under Privacy & Security → Accessibility. macOS only lists the app after it has asked once."
    }

    var symbol: String { "accessibility" }

    var isRequired: Bool { true }

    /// True when macOS shows a consent prompt that we can trigger ourselves.
    var canPrompt: Bool { true }

    // MARK: - Status

    @MainActor
    func status() -> PermissionStatus {
        if AXIsProcessTrusted() { return .granted }
        // The API has no "not determined" state; remember whether the consent
        // prompt was already shown so the wizard can tell "not asked" from
        // "denied".
        return wasRequested ? .denied : .notDetermined
    }

    // MARK: - Request

    @MainActor
    func request() async {
        // Registers heycast in the Accessibility list and offers to open the
        // pane; once answered, only the pane can change the answer. The SDK
        // exposes kAXTrustedCheckOptionPrompt as a mutable global, which
        // Swift 6 rejects off a nonisolated context; the documented value is
        // a stable string.
        UserDefaults.standard.set(true, forKey: requestedKey)
        _ = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        )
    }

    @MainActor
    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Label for the primary button on a permission step.
    func actionLabel(for status: PermissionStatus) -> String {
        canPrompt && status == .notDetermined ? "Ask for Access" : "Open System Settings"
    }

    // MARK: - Private

    private var requestedKey: String { "permission.requested.\(rawValue)" }

    private var wasRequested: Bool {
        UserDefaults.standard.bool(forKey: requestedKey)
    }
}
