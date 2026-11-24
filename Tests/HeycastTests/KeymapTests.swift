import Testing

@testable import Heycast

@Suite struct KeymapTests {
    @Test func defaultsCoverEveryBuiltInAction() {
        let keymap = Keymap.default

        #expect(keymap[.palette] == .default)
        #expect(keymap[.snippets] == .snippetDefault)
    }

    @Test func configuredShortcutsOverrideDefaults() {
        let keymap = AppConfig(
            keymaps: ["palette": "cmd+k", "snippets": "alt+s"]
        ).resolvedKeymap()

        #expect(keymap[.palette]?.displayString == "⌘K")
        #expect(keymap[.snippets]?.displayString == "⌥S")
    }

    @Test func emptyBindingDisablesAction() {
        let keymap = AppConfig(keymaps: ["snippets": "  "]).resolvedKeymap()

        #expect(keymap[.palette] == .default)
        #expect(keymap[.snippets] == nil)
    }

    @Test func invalidBindingFallsBackToActionDefault() {
        let keymap = AppConfig(
            keymaps: ["palette": "ctrl+hyper+space", "snippets": "ctrl+hyper+s"]
        ).resolvedKeymap()

        #expect(keymap[.palette] == .default)
        #expect(keymap[.snippets] == .snippetDefault)
    }

    @Test func duplicateShortcutKeepsFirstAction() {
        let keymap = AppConfig(
            keymaps: ["palette": "alt+space", "snippets": "alt+space"]
        ).resolvedKeymap()

        #expect(keymap[.palette] == .default)
        #expect(keymap[.snippets] == nil)
    }

    @Test func unknownActionsAreIgnored() {
        let keymap = AppConfig(
            keymaps: ["windowLeft": "ctrl+alt+left"]
        ).resolvedKeymap()

        #expect(keymap == .default)
    }

    @Test func issuesExplainInvalidAndDuplicateShortcuts() {
        let config = AppConfig(keymaps: [
            "palette": "ctl+space",
            "snippets": "ctrl+alt+k",
            "window.left": "ctrl+alt+k",
            "windowLeft": "ctrl+alt+left",
        ])
        let issues = config.keymapIssues()

        #expect(issues[.palette]?.contains("not a valid shortcut") == true)
        #expect(issues[.snippets] == nil)
        #expect(issues[.window(.left)]?.contains("Open Snippets") == true)
        #expect(config.resolvedKeymap()[.window(.left)] == nil)
        #expect(config.unknownKeymapActions == ["windowLeft"])
    }

    @Test func validConfigHasNoIssues() {
        let config = AppConfig(keymaps: ["palette": "cmd+shift+k", "snippets": ""])
        #expect(config.keymapIssues().isEmpty)
        #expect(config.unknownKeymapActions.isEmpty)
    }

    @Test func defaultsCoverWindowActions() {
        let keymap = Keymap.default

        #expect(keymap[.window(.left)]?.displayString == "⌃⌥←")
        #expect(keymap[.window(.right)]?.displayString == "⌃⌥→")
        #expect(keymap[.window(.top)]?.displayString == "⌃⌥↑")
        #expect(keymap[.window(.bottom)]?.displayString == "⌃⌥↓")
        #expect(keymap[.window(.maximize)]?.displayString == "⌃⌥Return")
        #expect(keymap[.window(.center)]?.displayString == "⌃⌥C")
        #expect(keymap[.window(.topLeft)] == nil)
    }

    @Test func configuredQuarterBindingIsAvailable() {
        let keymap = AppConfig(
            keymaps: ["window.topLeft": "ctrl+alt+1"]
        ).resolvedKeymap()

        #expect(keymap[.window(.topLeft)]?.displayString == "⌃⌥1")
    }

    @Test func windowNamesUseTheDotNamespace() {
        #expect(KeymapAction(rawValue: "window.left") == .window(.left))
        #expect(KeymapAction(rawValue: "window.topLeft") == .window(.topLeft))
        #expect(KeymapAction(rawValue: "window") == nil)
        #expect(KeymapAction(rawValue: "window.unknown") == nil)
        #expect(KeymapAction(rawValue: "window.top-left") == nil)
    }

    @Test func duplicateWindowShortcutKeepsFirstAction() {
        let keymap = AppConfig(
            keymaps: [
                "window.left": "ctrl+alt+left",
                "window.right": "ctrl+alt+left",
            ]
        ).resolvedKeymap()

        #expect(keymap[.window(.left)] != nil)
        #expect(keymap[.window(.right)] == nil)
    }

    @Test func windowActionCannotStealAnEarlierAction() {
        let keymap = AppConfig(
            keymaps: ["window.left": "alt+space"]
        ).resolvedKeymap()

        #expect(keymap[.palette] == .default)
        #expect(keymap[.window(.left)] == nil)
    }
}
