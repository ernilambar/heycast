import Foundation

/// A command that can be bound to a global shortcut. Add future commands here;
/// `keymaps` in `config.json` is keyed by the raw value. Grouped commands use a
/// dot namespace in the raw value (`window.left`), not nested config objects.
enum KeymapAction: String, CaseIterable, Sendable {
    case palette
    case snippets

    /// Shortcut used when `config.json` omits the action. `nil` keeps the
    /// action disabled until the user binds it.
    var defaultShortcut: HotKey? {
        switch self {
        case .palette: .default
        case .snippets: .snippetDefault
        }
    }

    /// Title in the status-bar menu, or `nil` for a hotkey-only action.
    var menuTitle: String? {
        switch self {
        case .palette: "Open Palette"
        case .snippets: "Open Snippets"
        }
    }
}

/// Resolved global shortcuts for every known action.
struct Keymap: Equatable, Sendable {
    private let shortcuts: [KeymapAction: HotKey]

    static let `default` = Keymap(
        shortcuts: Dictionary(
            uniqueKeysWithValues: KeymapAction.allCases.compactMap { action in
                action.defaultShortcut.map { (action, $0) }
            }
        )
    )

    init(shortcuts: [KeymapAction: HotKey]) {
        self.shortcuts = shortcuts
    }

    subscript(action: KeymapAction) -> HotKey? {
        shortcuts[action]
    }
}