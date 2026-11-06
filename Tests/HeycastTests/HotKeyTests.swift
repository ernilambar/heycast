import Carbon.HIToolbox
import Testing

@testable import Heycast

@Suite struct HotKeyTests {
    @Test func defaultIsOptionSpace() {
        #expect(HotKey.default.keyCode == UInt32(kVK_Space))
        #expect(HotKey.default.modifiers == UInt32(optionKey))
        #expect(HotKey.default.keyEquivalent == " ")
        #expect(HotKey.default.displayString == "⌥Space")
        #expect(HotKey.default.menuModifiers == [.option])
    }

    @Test func snippetDefaultIsOptionShiftSpace() {
        #expect(HotKey.snippetDefault.keyCode == UInt32(kVK_Space))
        #expect(HotKey.snippetDefault.modifiers == UInt32(optionKey | shiftKey))
        #expect(HotKey.snippetDefault.displayString == "⌥⇧Space")
        #expect(HotKey.snippetDefault.menuModifiers == [.option, .shift])
    }

    @Test func parsesModifierAliasesCaseAndWhitespace() {
        let expected = HotKey(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(cmdKey | shiftKey),
            keyEquivalent: "k",
            keyName: "K"
        )

        #expect(HotKey.parse(" CMD + Shift + K ") == expected)
        #expect(HotKey.parse("command+shift+k") == expected)
    }

    @Test func displayUsesCanonicalModifierOrder() {
        let hotKey = HotKey.parse("shift+cmd+ctrl+alt+space")
        #expect(hotKey?.displayString == "⌃⌥⇧⌘Space")
        #expect(hotKey?.menuModifiers == [.control, .option, .shift, .command])
    }

    @Test func parsesNamedPunctuationAndFunctionKeys() {
        #expect(HotKey.parse("ctrl+return")?.keyCode == UInt32(kVK_Return))
        #expect(HotKey.parse("ctrl+esc")?.keyEquivalent == "\u{1b}")
        #expect(HotKey.parse("ctrl+;")?.keyCode == UInt32(kVK_ANSI_Semicolon))
        #expect(HotKey.parse("ctrl+up")?.keyName == "↑")
        #expect(HotKey.parse("ctrl+f12")?.keyCode == UInt32(kVK_F12))
    }

    @Test func rejectsShortcutsThatWouldBreakTyping() {
        #expect(HotKey.parse("space") == nil)
        #expect(HotKey.parse("shift+space") == nil)
        #expect(HotKey.parse("ctrl") == nil)
    }

    @Test func rejectsUnknownOrMalformedShortcuts() {
        #expect(HotKey.parse("ctrl+hyper+space") == nil)
        #expect(HotKey.parse("ctrl+space+k") == nil)
        #expect(HotKey.parse("ctrl++space") == nil)
        #expect(HotKey.parse("") == nil)
    }

    @Test func configStringRoundTripsThroughParse() {
        for binding in [
            "alt+space",
            "alt+shift+space",
            "ctrl+alt+left",
            "shift+cmd+3",
            "ctrl+alt+f12",
            "cmd+;",
            "ctrl+alt+return",
        ] {
            let hotKey = HotKey.parse(binding)
            #expect(hotKey?.configString == binding)
            #expect(hotKey.flatMap { HotKey.parse($0.configString) } == hotKey)
        }
    }

    @Test func recordedKeyPressNeedsAPrimaryModifier() {
        #expect(HotKey.from(keyCode: UInt32(kVK_ANSI_A), modifiers: 0) == nil)
        #expect(
            HotKey.from(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(shiftKey)) == nil
        )
        #expect(
            HotKey.from(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey))?
                .configString == "cmd+a"
        )
        #expect(HotKey.from(keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(optionKey))?
            .configString == "alt+`")
    }
}
