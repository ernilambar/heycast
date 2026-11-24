import Carbon.HIToolbox
import Foundation

/// Shortcuts macOS owns globally.
///
/// `RegisterEventHotKey` can succeed for a combination the system also uses,
/// so registration is not proof the key is free: Spotlight's `⌘Space`, the
/// input-source switcher and Mission Control are reserved by the window server,
/// not by another app's hotkey. The settings window compares every binding
/// against this table instead of trusting the registration result alone.
enum SystemShortcut: String, CaseIterable, Sendable {
    case spotlight
    case inputSource
    case emojiAndSymbols
    case applicationSwitcher
    case missionControl
    case applicationWindows
    case moveLeftSpace
    case moveRightSpace
    case screenshot
    case lockScreen
    case forceQuit
    case finderSearch

    var title: String {
        switch self {
        case .spotlight: "Spotlight"
        case .inputSource: "Input source switching"
        case .emojiAndSymbols: "Emoji & Symbols"
        case .applicationSwitcher: "Application switcher"
        case .missionControl: "Mission Control"
        case .applicationWindows: "Application windows"
        case .moveLeftSpace: "Move left a space"
        case .moveRightSpace: "Move right a space"
        case .screenshot: "Screenshot"
        case .lockScreen: "Lock Screen"
        case .forceQuit: "Force Quit"
        case .finderSearch: "Finder search"
        }
    }

    /// Default config spellings, parsed through `HotKey.parse` so the table
    /// cannot drift from the parser, each paired with its ID in macOS's
    /// `AppleSymbolicHotKeys`. A `nil` ID marks a shortcut System Settings
    /// cannot disable or rebind, so it is always reserved.
    var bindings: [(id: Int?, binding: String)] {
        switch self {
        case .spotlight: [(64, "cmd+space")]
        case .inputSource: [(60, "ctrl+space")]
        case .emojiAndSymbols: [(nil, "ctrl+cmd+space")]
        case .applicationSwitcher: [(nil, "cmd+tab")]
        case .missionControl: [(32, "ctrl+up")]
        case .applicationWindows: [(33, "ctrl+down")]
        case .moveLeftSpace: [(79, "ctrl+left")]
        case .moveRightSpace: [(81, "ctrl+right")]
        case .screenshot: [(28, "shift+cmd+3"), (30, "shift+cmd+4"), (184, "shift+cmd+5")]
        case .lockScreen: [(nil, "ctrl+cmd+q")]
        case .forceQuit: [(nil, "alt+cmd+escape")]
        case .finderSearch: [(65, "alt+cmd+space")]
        }
    }
}

enum SystemShortcuts {
    /// Combinations macOS currently reserves, keyed to their owner.
    ///
    /// `symbolicHotKeys` is the `AppleSymbolicHotKeys` dictionary from
    /// `com.apple.symbolichotkeys`. An entry with `enabled = 0` frees its
    /// combination; an entry with parameters replaces the default binding with
    /// the user's own. A missing entry keeps the default.
    static func reservations(
        from symbolicHotKeys: [String: Any]? = currentSymbolicHotKeys()
    ) -> [HotKey: SystemShortcut] {
        var reservations: [HotKey: SystemShortcut] = [:]
        for shortcut in SystemShortcut.allCases {
            for (id, binding) in shortcut.bindings {
                let entry = id.flatMap { symbolicHotKeys?[String($0)] as? [String: Any] }
                if let enabled = entry?["enabled"] as? Bool, !enabled { continue }
                // A stored binding wins even when it is unrepresentable or
                // unassigned; only a missing one falls back to the default.
                let hotKey = entry?["value"] != nil
                    ? entry.flatMap(customHotKey)
                    : HotKey.parse(binding)
                guard let hotKey else { continue }
                reservations[hotKey] = shortcut
            }
        }
        return reservations
    }

    /// Reads the live macOS setting; a local preferences read, no TCC prompt.
    static func currentSymbolicHotKeys() -> [String: Any]? {
        let domain = "com.apple.symbolichotkeys" as CFString
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, domain)
            as? [String: Any]
    }

    /// `parameters` is `[character, keyCode, modifierFlags]` with AppKit
    /// modifier masks; arrow keys also carry the function and numeric-pad bits,
    /// which `HotKey` does not model.
    private static func customHotKey(_ entry: [String: Any]) -> HotKey? {
        guard let value = entry["value"] as? [String: Any],
              let parameters = value["parameters"] as? [Int],
              parameters.count == 3
        else { return nil }
        let flags = parameters[2]
        var modifiers: UInt32 = 0
        if flags & 0x20000 != 0 { modifiers |= UInt32(shiftKey) }
        if flags & 0x40000 != 0 { modifiers |= UInt32(controlKey) }
        if flags & 0x80000 != 0 { modifiers |= UInt32(optionKey) }
        if flags & 0x100000 != 0 { modifiers |= UInt32(cmdKey) }
        return HotKey.from(keyCode: UInt32(parameters[1]), modifiers: modifiers)
    }
}
