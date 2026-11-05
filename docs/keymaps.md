# Keymaps

Global shortcuts live under `keymaps` in `config.json`. Each key is an action
name; each value is a shortcut string.

```json
{
  "keymaps": {
    "palette": "ctrl+space",
    "snippets": "ctrl+shift+space",
    "window.topLeft": "ctrl+alt+1"
  }
}
```

## Actions

| Action | Default | Does |
|---|---|---|
| `palette` | `ctrl+space` | Toggle the full apps-and-snippets palette |
| `snippets` | `ctrl+shift+space` | Open the palette with snippets only |
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

Window commands act on the focused window and need Accessibility. All of them
are also in the menu-bar item's "Window" submenu.

## Shortcut syntax

Join modifiers and one key with `+`: `cmd+shift+k`, `alt+space`, `ctrl+f1`.

- **Modifiers:** `ctrl`/`control`, `alt`/`opt`/`option`, `cmd`/`command`,
  `shift`. At least one of control, option or command is required.
- **Keys:** letters, digits, `space`, `return`, `tab`, `escape`, arrows,
  `home`, `end`, `pageup`, `pagedown`, `delete`, `backspace`,
  `forwarddelete`, punctuation marks and `f1`…`f20`.

## Rules

- A missing action uses its default. Quarter commands have none.
- `""` disables an action.
- Unknown action names are logged and ignored.
- An invalid shortcut is logged and falls back to the action's default.
- A duplicate shortcut is logged; the first action wins, in table order.
- Registration fails when another app or a system shortcut owns the
  combination. That is logged too.
- Changes apply on the next launch.
