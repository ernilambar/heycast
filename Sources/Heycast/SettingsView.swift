import AppKit
import SwiftUI

/// Settings window content. Everything writes through `SettingsModel`, which
/// saves `config.json` and asks the app to re-register hotkeys in place.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    private static let snippetsDocs = URL(string: "https://github.com/ernilambar/heycast/blob/main/docs/snippets.md")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    generalSection
                    snippetsSection
                    shortcutSection
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }

            Divider()

            footer
        }
        .frame(width: 580, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Heycast Settings")
                .font(.system(size: 20, weight: .semibold))
            Text("Shortcuts, snippets and login. Changes apply immediately.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 36)
        .padding(.bottom, 16)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else {
                Text("Saved to config.json.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 12)

            Button("Reveal") { model.revealConfigFile() }
                .buttonStyle(.link)
                .font(.system(size: 11))
            Button("Edit Config…") { model.editConfig() }
                .buttonStyle(.link)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }

    // MARK: - Shortcuts

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Shortcuts")

            if model.hasIssues {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("A shortcut below belongs to another app or to macOS. Change it so Heycast can use it.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 12))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.orange.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }

            VStack(spacing: 0) {
                ForEach(KeymapAction.allCases, id: \.self) { action in
                    shortcutRow(action)

                    if action != KeymapAction.allCases.last {
                        Divider()
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
        }
    }

    private func shortcutRow(_ action: KeymapAction) -> some View {
        let hotKey = model.shortcut(for: action)
        let isRecording = model.recording == action

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.settingsTitle)
                    .font(.system(size: 13))

                if let issue = model.issues[action] {
                    Text(issue)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            if isRecording {
                Text("Press a shortcut…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button("Cancel") { model.cancelRecording() }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            } else {
                Text(hotKey?.displayString ?? "Disabled")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(hotKey == nil ? .secondary : .primary)
                    .frame(minWidth: 92, alignment: .leading)

                Button(hotKey == nil ? "Set" : "Change") {
                    model.beginRecording(action)
                }
                .font(.system(size: 12))

                if hotKey != nil, model.issues[action] != nil {
                    Button("Change shortcut") {
                        model.beginRecording(action)
                    }
                    .font(.system(size: 12))
                }

                Button("Remove") { model.setShortcut(nil, for: action) }
                    .font(.system(size: 12))
                    .disabled(hotKey == nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    // MARK: - Snippets

    private var snippetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Snippets")

            HStack(spacing: 12) {
                Text(model.snippetsPath)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Spacer(minLength: 12)

                Button("Reveal") { model.revealSnippetsDirectory() }
                    .font(.system(size: 12))
                Button("Choose…") { model.chooseSnippetsDirectory() }
                    .font(.system(size: 12))
                Button("Use Default") { model.useDefaultSnippetsDirectory() }
                    .font(.system(size: 12))
                    .disabled(model.isUsingDefaultSnippetsDirectory)
                    .help("Clear the custom folder and return to the default snippets folder.")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )

            Text("The folder is created automatically; keep it empty to have no snippets.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link("Snippets format guide", destination: Self.snippetsDocs)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("General")

            VStack(alignment: .leading, spacing: 6) {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { model.launchAtLogin.isOn },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .toggleStyle(.switch)
                .font(.system(size: 13))

                Text(LoginItem.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if model.launchAtLogin == .requiresApproval {
                    Button("Open Login Items") { LoginItem.openSettings() }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}
