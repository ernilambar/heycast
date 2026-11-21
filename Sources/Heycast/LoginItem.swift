import AppKit
import ServiceManagement

/// Launch at login through `SMAppService.mainApp`, the supported replacement
/// for a Login Items helper bundle.
///
/// Registration can land in `.requiresApproval`: macOS lists the app in
/// System Settings → General → Login Items and waits for the user, so the
/// caller must show that state instead of pretending the toggle worked.
@MainActor
enum LoginItem {
    enum State: Equatable, Sendable {
        case enabled
        case requiresApproval
        case disabled
        case unavailable

        var isOn: Bool { self == .enabled }
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        // A fresh install reports notFound until the first register() call;
        // that is "off", not "broken". Registration still works from here.
        case .notRegistered, .notFound: .disabled
        @unknown default: .unavailable
        }
    }

    /// Adds or removes the login item and returns the state macOS reports
    /// afterwards. Throws only when the request itself fails; an approval
    /// requirement is a normal result, not an error.
    ///
    /// `notFound` is not treated as "give up": a build that LaunchServices has
    /// not recorded yet can still register, so the call is attempted and its
    /// error surfaced instead of hiding behind a disabled toggle.
    @discardableResult
    static func setEnabled(_ enabled: Bool) throws -> State {
        let service = SMAppService.mainApp
        if enabled {
            switch service.status {
            case .enabled, .requiresApproval:
                break
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                try service.register()
            }
        } else if service.status != .notRegistered {
            try service.unregister()
        }
        return state
    }

    static func openSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    static var summary: String {
        switch state {
        case .enabled: "Heycast opens when you log in."
        case .requiresApproval: "Allow Heycast in System Settings → Login Items."
        case .disabled: "Heycast does not open when you log in."
        case .unavailable: "Launch at Login is unavailable for this build."
        }
    }
}
