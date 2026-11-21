import AppKit
import SwiftUI

/// Step-by-step setup for the TCC permissions heycast needs. One permission
/// per page, then a summary the user can loop back from.
struct PermissionWizardView: View {
    @ObservedObject var model: PermissionWizardModel
    /// `true` only when the user pressed Finish, so the caller can record
    /// setup as done without treating "Set Up Later" as completion.
    let onFinish: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            Group {
                switch model.step {
                case .moveToApplications:
                    MoveToApplicationsStepView()
                case .permission(let permission):
                    PermissionStepView(
                        permission: permission,
                        status: model.status(for: permission),
                        isRequesting: model.pending == permission,
                        action: { model.grant(permission) }
                    )
                case .summary:
                    PermissionSummaryView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 26)
            .padding(.vertical, 22)

            Divider()

            footer
        }
        .frame(width: 560, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Heycast Setup")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Step \(model.stepNumber) of \(model.totalSteps)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: model.stepFraction)
                .progressViewStyle(.linear)
                .controlSize(.small)
        }
        // fullSizeContentView puts the traffic lights over the top-leading
        // corner, so the header starts below them.
        .padding(.horizontal, 26)
        .padding(.top, 40)
        .padding(.bottom, 18)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Set Up Later") { onFinish(false) }
                .buttonStyle(.link)
                .font(.system(size: 12))

            Spacer()

            if model.canGoBack {
                Button("Back") { model.back() }
            }

            Button(model.isSummary ? "Finish" : "Continue") {
                if model.isSummary {
                    onFinish(true)
                } else {
                    model.advance()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(model.isSummary && !model.allRequiredGranted)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
    }
}

// MARK: - Permission step

private struct PermissionStepView: View {
    let permission: Permission
    let status: PermissionStatus
    let isRequesting: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: permission.symbol)
                    .font(.system(size: 26))
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34, alignment: .leading)

                Spacer()

                PermissionStatusBadge(status: status)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(permission.title)
                        .font(.system(size: 24, weight: .semibold))

                    if permission.isRequired {
                        Text("Required")
                            .font(.system(size: 10, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.25), in: Capsule())
                    }
                }

                Text(permission.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(permission.instruction)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(nsColor: .textBackgroundColor).opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor))
                )

            if status.isGranted {
                Label("Access granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Button(action: action) {
                            if isRequesting {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("Waiting for macOS…")
                                }
                            } else {
                                Text(permission.actionLabel(for: status))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRequesting)

                        if permission.canPrompt, status == .notDetermined {
                            Button("Open System Settings") { permission.openSettings() }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Move to Applications

/// macOS records Accessibility and Login Items against the bundle path, so a
/// copy in a build folder or a Downloads unzip starts with grants that break
/// the moment the user moves it. The step disappears once the app lives in
/// `/Applications`, which is where the cask installs it.
private struct MoveToApplicationsStepView: View {
    private var appURL: URL { Bundle.main.bundleURL }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 26))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Move Heycast to Applications")
                    .font(.system(size: 24, weight: .semibold))

                Text(
                    "Heycast is running from \(appURL.deletingLastPathComponent().path). macOS ties Accessibility and Login Items to the app's location, so move it to /Applications before granting anything."
                )
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Text(
                "Drag Heycast.app into Applications, then open it from there and reopen this setup from the menu-bar item."
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .textBackgroundColor).opacity(0.6),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )

            HStack(spacing: 12) {
                Button("Show Heycast in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([appURL])
                }
                Button("Open Applications") {
                    NSWorkspace.shared.open(
                        URL(fileURLWithPath: "/Applications", isDirectory: true)
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Summary

private struct PermissionSummaryView: View {
    @ObservedObject var model: PermissionWizardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.allRequiredGranted ? "You're all set" : "Almost there")
                .font(.system(size: 24, weight: .semibold))

            Text(
                model.allRequiredGranted
                    ? "heycast has the access it needs. You can change this later in System Settings or from the menu-bar item."
                    : "heycast still needs the access marked Required. Grant it now, or set up later and do it from the menu-bar item."
            )
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(model.permissions) { permission in
                    row(for: permission)

                    if permission != model.permissions.last {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )

            Spacer(minLength: 0)
        }
    }

    private func row(for permission: Permission) -> some View {
        let status = model.status(for: permission)

        return Button {
            model.jump(to: permission)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: status.symbol)
                    .foregroundStyle(status.tint)
                    .frame(width: 18)

                Text(permission.title)
                    .font(.system(size: 13))

                Spacer()

                if permission.isRequired && !status.isGranted {
                    Text("Required")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status presentation

private struct PermissionStatusBadge: View {
    let status: PermissionStatus

    var body: some View {
        Label(status.label, systemImage: status.symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(status.tint.opacity(0.12), in: Capsule())
    }
}

private extension PermissionStatus {
    var label: String {
        switch self {
        case .granted: "Granted"
        case .denied: "Denied"
        case .notDetermined: "Not granted"
        case .restricted: "Restricted"
        }
    }

    var symbol: String {
        switch self {
        case .granted: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notDetermined: "circle.dashed"
        case .restricted: "lock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .granted: .green
        case .denied: .red
        case .notDetermined: .secondary
        case .restricted: .orange
        }
    }
}
