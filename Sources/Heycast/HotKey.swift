import AppKit
import Carbon.HIToolbox

/// A global shortcut expressed as a Carbon key code plus Carbon modifier flags.
///
/// `config.json` stores the human-readable form (`"ctrl+space"`); this type
/// parses it and keeps the pieces Carbon and AppKit need.
struct HotKey: Hashable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    /// AppKit key equivalent for the status-bar menu; `nil` for keys AppKit
    /// cannot represent as a menu shortcut.
    let keyEquivalent: String?
    /// Human-readable key name used in logs and the shortcut display.
    let keyName: String

    static let `default` = HotKey(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey),
        keyEquivalent: " ",
        keyName: "Space"
    )

    /// `⌃⇧Space` opens the palette limited to snippets.
    static let snippetDefault = HotKey(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey) | UInt32(shiftKey),
        keyEquivalent: " ",
        keyName: "Space"
    )

    /// Shortcut identity is the physical key plus modifiers; display metadata
    /// does not make two bindings distinct.
    static func == (lhs: HotKey, rhs: HotKey) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }

    /// Shortcut as shown in logs, e.g. `⌃Space` or `⌘⇧K`.
    var displayString: String { modifierSymbols + keyName }

    /// AppKit modifier flags matching `modifiers`, for the menu item.
    var menuModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }

    /// Parses `"ctrl+space"`, `"cmd+shift+k"`, and the like.
    ///
    /// Returns `nil` for unknown keys, missing keys, or a shortcut without at
    /// least one of control, option or command: capturing a bare key or
    /// shift-only combination globally would make normal typing unusable.
    static func parse(_ raw: String) -> HotKey? {
        var modifiers: UInt32 = 0
        var keyToken: String?

        for piece in raw.split(separator: "+", omittingEmptySubsequences: false) {
            let token = piece.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !token.isEmpty else { return nil }

            if let flag = modifierAliases[token] {
                modifiers |= flag
                continue
            }

            guard keyToken == nil else { return nil }
            keyToken = token
        }

        guard let keyToken,
              let key = keys[keyToken],
              modifiers & primaryModifiers != 0
        else { return nil }

        return HotKey(
            keyCode: UInt32(key.keyCode),
            modifiers: modifiers,
            keyEquivalent: key.equivalent,
            keyName: key.name
        )
    }

    private var modifierSymbols: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols
    }

    private static var primaryModifiers: UInt32 {
        UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)
    }

    private static let modifierAliases: [String: UInt32] = [
        "ctrl": UInt32(controlKey),
        "control": UInt32(controlKey),
        "alt": UInt32(optionKey),
        "opt": UInt32(optionKey),
        "option": UInt32(optionKey),
        "shift": UInt32(shiftKey),
        "cmd": UInt32(cmdKey),
        "command": UInt32(cmdKey),
    ]

    private struct KeyDefinition: Sendable {
        let keyCode: Int
        let name: String
        let equivalent: String?
    }

    /// Key tokens are US-layout positions because Carbon hotkeys are physical
    /// key codes; the same shortcut triggers the same key on every layout.
    private static let keys: [String: KeyDefinition] = {
        var keys: [String: KeyDefinition] = [:]

        func add(
            _ aliases: [String],
            keyCode: Int,
            name: String,
            equivalent: String?
        ) {
            let definition = KeyDefinition(
                keyCode: keyCode,
                name: name,
                equivalent: equivalent
            )
            for alias in aliases {
                keys[alias] = definition
            }
        }

        let letters: [(Int, String)] = [
            (kVK_ANSI_A, "a"), (kVK_ANSI_B, "b"), (kVK_ANSI_C, "c"),
            (kVK_ANSI_D, "d"), (kVK_ANSI_E, "e"), (kVK_ANSI_F, "f"),
            (kVK_ANSI_G, "g"), (kVK_ANSI_H, "h"), (kVK_ANSI_I, "i"),
            (kVK_ANSI_J, "j"), (kVK_ANSI_K, "k"), (kVK_ANSI_L, "l"),
            (kVK_ANSI_M, "m"), (kVK_ANSI_N, "n"), (kVK_ANSI_O, "o"),
            (kVK_ANSI_P, "p"), (kVK_ANSI_Q, "q"), (kVK_ANSI_R, "r"),
            (kVK_ANSI_S, "s"), (kVK_ANSI_T, "t"), (kVK_ANSI_U, "u"),
            (kVK_ANSI_V, "v"), (kVK_ANSI_W, "w"), (kVK_ANSI_X, "x"),
            (kVK_ANSI_Y, "y"), (kVK_ANSI_Z, "z"),
        ]
        for (keyCode, letter) in letters {
            add([letter], keyCode: keyCode, name: letter.uppercased(), equivalent: letter)
        }

        let digits: [(Int, String)] = [
            (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"),
            (kVK_ANSI_3, "3"), (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"),
            (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"), (kVK_ANSI_8, "8"),
            (kVK_ANSI_9, "9"),
        ]
        for (keyCode, digit) in digits {
            add([digit], keyCode: keyCode, name: digit, equivalent: digit)
        }

        add(["space"], keyCode: kVK_Space, name: "Space", equivalent: " ")
        add(["return", "enter"], keyCode: kVK_Return, name: "Return", equivalent: "\r")
        add(["tab"], keyCode: kVK_Tab, name: "Tab", equivalent: "\t")
        add(["escape", "esc"], keyCode: kVK_Escape, name: "Esc", equivalent: "\u{1b}")
        add(["delete", "backspace"], keyCode: kVK_Delete, name: "Delete", equivalent: "\u{8}")
        add(
            ["forwarddelete", "deleteforward"],
            keyCode: kVK_ForwardDelete,
            name: "Forward Delete",
            equivalent: "\u{7f}"
        )

        let punctuation: [(String, Int)] = [
            (";", kVK_ANSI_Semicolon), ("'", kVK_ANSI_Quote),
            (",", kVK_ANSI_Comma), (".", kVK_ANSI_Period),
            ("/", kVK_ANSI_Slash), ("\\", kVK_ANSI_Backslash),
            ("[", kVK_ANSI_LeftBracket), ("]", kVK_ANSI_RightBracket),
            ("-", kVK_ANSI_Minus), ("=", kVK_ANSI_Equal),
            ("`", kVK_ANSI_Grave),
        ]
        for (character, keyCode) in punctuation {
            add([character], keyCode: keyCode, name: character, equivalent: character)
        }

        let navigation: [(String, Int, String, Int)] = [
            ("left", kVK_LeftArrow, "←", 0xF702),
            ("right", kVK_RightArrow, "→", 0xF703),
            ("down", kVK_DownArrow, "↓", 0xF701),
            ("up", kVK_UpArrow, "↑", 0xF700),
            ("home", kVK_Home, "Home", 0xF729),
            ("end", kVK_End, "End", 0xF72B),
            ("pageup", kVK_PageUp, "Page Up", 0xF72C),
            ("pagedown", kVK_PageDown, "Page Down", 0xF72D),
        ]
        for (alias, keyCode, name, equivalent) in navigation {
            add(
                [alias],
                keyCode: keyCode,
                name: name,
                equivalent: String(UnicodeScalar(UInt32(equivalent))!)
            )
        }

        let functionKeys: [(Int, Int)] = [
            (kVK_F1, 1), (kVK_F2, 2), (kVK_F3, 3), (kVK_F4, 4),
            (kVK_F5, 5), (kVK_F6, 6), (kVK_F7, 7), (kVK_F8, 8),
            (kVK_F9, 9), (kVK_F10, 10), (kVK_F11, 11), (kVK_F12, 12),
            (kVK_F13, 13), (kVK_F14, 14), (kVK_F15, 15), (kVK_F16, 16),
            (kVK_F17, 17), (kVK_F18, 18), (kVK_F19, 19), (kVK_F20, 20),
        ]
        for (keyCode, number) in functionKeys {
            add(
                ["f\(number)"],
                keyCode: keyCode,
                name: "F\(number)",
                equivalent: String(UnicodeScalar(UInt32(0xF704 + number - 1))!)
            )
        }

        return keys
    }()
}
