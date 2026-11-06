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

    /// Config spellings, parsed through `HotKey.parse` so the table cannot
    /// drift from the parser.
    var bindings: [String] {
        switch self {
        case .spotlight: ["cmd+space"]
        case .inputSource: ["ctrl+space"]
        case .emojiAndSymbols: ["ctrl+cmd+space"]
        case .applicationSwitcher: ["cmd+tab"]
        case .missionControl: ["ctrl+up"]
        case .applicationWindows: ["ctrl+down"]
        case .moveLeftSpace: ["ctrl+left"]
        case .moveRightSpace: ["ctrl+right"]
        case .screenshot: ["shift+cmd+3", "shift+cmd+4", "shift+cmd+5"]
        case .lockScreen: ["ctrl+cmd+q"]
        case .forceQuit: ["alt+cmd+escape"]
        case .finderSearch: ["alt+cmd+space"]
        }
    }
}

enum SystemShortcuts {
    /// The system feature that owns `hotKey`, or `nil` when the combination is
    /// not one of the well-known reserved shortcuts.
    static func owner(of hotKey: HotKey) -> SystemShortcut? {
        reservations[hotKey]
    }

    private static let reservations: [HotKey: SystemShortcut] = {
        var reservations: [HotKey: SystemShortcut] = [:]
        for shortcut in SystemShortcut.allCases {
            for binding in shortcut.bindings {
                guard let hotKey = HotKey.parse(binding) else { continue }
                reservations[hotKey] = shortcut
            }
        }
        return reservations
    }()
}
