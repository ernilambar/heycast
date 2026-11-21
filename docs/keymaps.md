# Keymaps

Global shortcuts live under `keymaps` in `config.json`. Each key is an action
name; each value is a shortcut string.

```json
{
  "keymaps": {
    "palette": "alt+space",
    "snippets": "alt+shift+space",
    "window.topLeft": "ctrl+alt+1"
  }
}
```

## Actions

| Action | Default | Does |
|---|---|---|
| `palette` | `alt+space` | Toggle the full apps-and-snippets palette |
| `snippets` | `alt+shift+space` | Open the palette with snippets only |
| `window.left` | `ctrl+alt+left` | Fill the left half |
| `window.right` | `ctrl+alt+right` | Fill the right half |
| `window.top` | `ctrl+alt+up` | Fill the top half |
| `window.bottom` | `ctrl+alt+down` | Fill the bottom half |
| `window.maximize` | `ctrl+alt+return` | Maximize the focused window |
| `window.center` | `ctrl+alt+c` | Center without resizing |
| `window.topLeft` | — | Top-left quarter |
| `window.topRight` | — | Top-right quarter |
| `window.bottomLeft` | — | Bottom-left quarter |
| `window.bottomRight` | — | Bottom-right quarter |
| `window.leftThird` | — | Fill the left third |
| `window.leftTwoThirds` | — | Fill the left two thirds |
| `window.rightThird` | — | Fill the right third |
| `window.rightTwoThirds` | — | Fill the right two thirds |
| `window.undo` | — | Undo the last window move, one step per window |

Window commands act on the focused window and need Accessibility. All of them
are also in the menu-bar item's "Window" submenu; thirds and undo ship unbound
and are used from that submenu. Each action applies one fixed layout — there is
no cycling. A full-screen window is left untouched and the attempt is logged,
so Heycast never forces a Space transition. Undo history is in memory only and
holds one step per window.

The defaults deliberately avoid the combinations macOS owns: no `⌘Space`
(Spotlight), no `⌃Space` (input sources), no `⌃↑`/`⌃↓` (Mission Control).
`⌘Space` still opens Spotlight on a default install.

## Shortcut syntax

Join modifiers and one key with `+`: `cmd+shift+k`, `alt+space`, `ctrl+f1`.

- **Modifiers:** `ctrl`/`control`, `alt`/`opt`/`option`, `cmd`/`command`,
  `shift`. At least one of control, option or command is required.
- **Keys:** letters, digits, `space`, `return`, `tab`, `escape`, arrows,
  `home`, `end`, `pageup`, `pagedown`, `delete`, `backspace`,
  `forwarddelete`, punctuation marks and `f1`…`f20`.

## Settings

"Settings…" in the menu-bar item lists every action with a recorder:

- **Change** captures the next key combination. A bare key or a shift-only
  combination is refused, because a global hotkey needs control, option or
  command to be safe.
- **Remove** writes `""` and disables the action.
- A shortcut owned by macOS (Spotlight, input sources, Mission Control,
  screenshots, …) or one whose registration failed is marked with a warning and
  a **Change shortcut** button. Registration success alone is not proof the key
  is free, so the settings window compares against the system's reserved list
  as well.

## Rules

- A missing action uses its default. Quarter commands have none.
- `""` disables an action.
- Unknown action names are logged and ignored.
- An invalid shortcut is logged and falls back to the action's default.
- A duplicate shortcut is logged; the first action wins, in table order.
- Registration fails when another app or a system shortcut owns the
  combination. The failure is shown in Settings, not only in the log.
- Changes apply immediately: the settings window writes `config.json` and the
  app re-registers hotkeys in place. A hand edit is picked up the same way.
