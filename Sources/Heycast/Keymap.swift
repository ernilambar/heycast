import Foundation

/// A command that can be bound to a global shortcut. Add future commands here;
/// `keymaps` in `config.json` is keyed by the raw value. Grouped commands use a
/// dot namespace in the raw value (`window.left`), not nested config objects.
enum KeymapAction: Hashable, CaseIterable, Sendable {
    case palette
    case snippets
    case window(WindowAction)

    static var allCases: [KeymapAction] {
        [.palette, .snippets] + WindowAction.allCases.map { .window($0) }
    }

    /// The `config.json` key for this command.
    var rawValue: String {
        switch self {
        case .palette: "palette"
        case .snippets: "snippets"
        case .window(let action): "window.\(action.rawValue)"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "palette":
            self = .palette
        case "snippets":
            self = .snippets
        default:
            guard rawValue.hasPrefix("window."),
                  let action = WindowAction(
                      rawValue: String(rawValue.dropFirst("window.".count))
                  )
            else { return nil }
            self = .window(action)
        }
    }

    /// Shortcut used when `config.json` omits the action. `nil` keeps the
    /// action disabled until the user binds it.
    var defaultShortcut: HotKey? {
        switch self {
        case .palette: .default
        case .snippets: .snippetDefault
        case .window(let action): action.defaultShortcut
        }
    }

    /// Title in the status-bar menu, or `nil` for a hotkey-only action.
    /// Window commands live in their own submenu.
    var menuTitle: String? {
        switch self {
        case .palette: "Open Palette"
        case .snippets: "Open Snippets"
        case .window: nil
        }
    }

    /// Row label in the settings window, where every action is listed.
    var settingsTitle: String {
        switch self {
        case .palette: "Open Palette"
        case .snippets: "Open Snippets"
        case .window(let action): "Window: \(action.title)"
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
