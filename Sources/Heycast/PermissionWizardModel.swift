import AppKit
import SwiftUI

/// Drives the permission wizard: which step is showing, what each permission
/// currently reports, and the in-flight consent request.
///
/// The wizard never opens by itself at launch: Accessibility is only needed
/// for snippets and window commands, so it is offered the first time one of
/// those is used, and always from the menu.
@MainActor
final class PermissionWizardModel: ObservableObject {
    enum Step: Equatable {
        /// Shown when the app runs from outside `/Applications`, where macOS
        /// registers permissions against a path that a later move breaks.
        case moveToApplications
        case permission(Permission)
        case summary
    }

    let permissions = Permission.allCases

    @Published private(set) var statuses: [Permission: PermissionStatus] = [:]
    @Published private(set) var step: Step = .permission(.accessibility)
    @Published private(set) var pending: Permission?
    @Published private(set) var launchAtLogin: LoginItem.State = .disabled

    private var steps: [Step] = []
    private var activationObserver: Any?

    var currentPermission: Permission? {
        if case .permission(let permission) = step { return permission }
        return nil
    }

    var isSummary: Bool { step == .summary }

    var totalSteps: Int { steps.isEmpty ? permissions.count + 1 : steps.count }

    var stepNumber: Int {
        guard let index = steps.firstIndex(of: step) else { return 1 }
        return index + 1
    }

    var stepFraction: Double { Double(stepNumber) / Double(totalSteps) }

    var canGoBack: Bool { stepNumber > 1 }

    var allRequiredGranted: Bool {
        permissions.filter(\.isRequired).allSatisfy { statuses[$0]?.isGranted == true }
    }

    func status(for permission: Permission) -> PermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    /// macOS keys a grant to the bundle path, so a copy running from a build
    /// folder or a Downloads unzip gets a grant that a later move loses.
    nonisolated static func needsMoveToApplications(for bundleURL: URL = Bundle.main.bundleURL) -> Bool {
        let path = bundleURL.standardizedFileURL.path
        return path != "/Applications" && !path.hasPrefix("/Applications/")
    }

    // MARK: - Lifecycle

    func start() {
        steps = (Self.needsMoveToApplications() ? [.moveToApplications] : [])
            + permissions.map(Step.permission)
            + [.summary]
        step = steps.first ?? .summary
        pending = nil
        refresh()
        // Permissions are granted in System Settings, so the app loses focus
        // and comes back. Re-read every status when that happens.
        guard activationObserver == nil else { return }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        guard let activationObserver else { return }
        NotificationCenter.default.removeObserver(activationObserver)
        self.activationObserver = nil
    }

    // MARK: - Navigation

    func advance() {
        refresh()
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        step = steps[index + 1]
    }

    func back() {
        refresh()
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
    }

    func jump(to permission: Permission) {
        step = .permission(permission)
        refresh()
    }

    // MARK: - Actions

    func refresh() {
        var updated: [Permission: PermissionStatus] = [:]
        for permission in permissions {
            updated[permission] = permission.status()
        }
        statuses = updated
        launchAtLogin = LoginItem.state
    }

    func grant(_ permission: Permission) {
        guard pending == nil else { return }
        guard permission.canPrompt, status(for: permission) == .notDetermined else {
            permission.openSettings()
            return
        }

        pending = permission
        Task {
            await permission.request()
            pending = nil
            refresh()
        }
    }

    /// Registers the login item. `requiresApproval` is a normal outcome: macOS
    /// waits for the user in System Settings, so send them there.
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            let state = try LoginItem.setEnabled(enabled)
            launchAtLogin = state
            if state == .requiresApproval {
                LoginItem.openSettings()
            }
        } catch {
            NSLog(
                "Heycast: cannot change Launch at Login: %@",
                error.localizedDescription
            )
            launchAtLogin = LoginItem.state
        }
    }
}
