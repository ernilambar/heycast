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
            keymaps: ["palette": "ctrl+space", "snippets": "ctrl+space"]
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
}
