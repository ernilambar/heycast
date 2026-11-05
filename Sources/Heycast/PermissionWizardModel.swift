import AppKit
import SwiftUI

/// Drives the permission wizard: which step is showing, what each permission
/// currently reports, and the in-flight consent request.
@MainActor
final class PermissionWizardModel: ObservableObject {
    enum Step: Equatable {
        case permission(Permission)
        case summary
    }

    let permissions = Permission.allCases

    @Published private(set) var statuses: [Permission: PermissionStatus] = [:]
    @Published private(set) var step: Step = .permission(.accessibility)
    @Published private(set) var pending: Permission?

    private var activationObserver: Any?

    var currentPermission: Permission? {
        if case .permission(let permission) = step { return permission }
        return nil
    }

    var isSummary: Bool { step == .summary }

    var totalSteps: Int { permissions.count + 1 }

    var stepNumber: Int {
        switch step {
        case .permission(let permission):
            (permissions.firstIndex(of: permission) ?? 0) + 1
        case .summary:
            totalSteps
        }
    }

    var stepFraction: Double { Double(stepNumber) / Double(totalSteps) }

    var canGoBack: Bool { stepNumber > 1 }

    var allRequiredGranted: Bool {
        permissions.filter(\.isRequired).allSatisfy { statuses[$0]?.isGranted == true }
    }

    func status(for permission: Permission) -> PermissionStatus {
        statuses[permission] ?? .notDetermined
    }

    // MARK: - Lifecycle

    func start() {
        step = .permission(permissions[0])
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
        switch step {
        case .permission(let permission):
            let index = permissions.firstIndex(of: permission) ?? 0
            step = index + 1 < permissions.count ? .permission(permissions[index + 1]) : .summary
        case .summary:
            break
        }
    }

    func back() {
        refresh()
        switch step {
        case .permission(let permission):
            let index = permissions.firstIndex(of: permission) ?? 0
            if index > 0 { step = .permission(permissions[index - 1]) }
        case .summary:
            step = .permission(permissions[permissions.count - 1])
        }
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
}
