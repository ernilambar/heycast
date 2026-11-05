# heycast

A macOS launcher palette and window manager. Press `⌃Space` anywhere, type a
few letters, hit `↩`, and the app you meant opens. Press `⌃⇧Space` to search
snippets only. `⌃⌥` plus an arrow snaps the focused window. Heycast lives in
the menu bar — no Dock icon, no main window.

## Install

- macOS 14 or later, Apple silicon.
- Requires build and install from source: see [CONTRIBUTING.md](CONTRIBUTING.md).

After installing, Heycast starts in the menu bar. There is nothing to launch
from Launchpad or Finder.

## Use

- `⌃Space` toggles the palette from any app.
- `⌃⇧Space` opens the palette with snippets only.
- `⌃⌥` plus an arrow fills that half of the screen, `⌃⌥↩` maximizes and
  `⌃⌥C` centers the focused window. All shortcuts are configurable; see
  [docs/keymaps.md](docs/keymaps.md).
- Click the menu-bar item to toggle the full palette.
- Right-click the menu-bar item for "Open Palette", "Open Snippets",
  "Window", "Edit Config…", "Permissions…" and "Quit Heycast".
- `↑`/`↓` moves the selection, `↩` launches the selected app or pastes the
  selected snippet, clicking a row does the same, `esc` or focusing another app
  closes the palette.
- Typing a snippet keyword in any app expands it in place; this needs
  Accessibility.

## Search

Type to filter apps in `/Applications`, `/System/Applications` and
`~/Applications`, plus snippets. Frequently and recently launched apps rank
higher. Details: [docs/search.md](docs/search.md).

## Config

All app files live in `~/Library/Application Support/net.nilambar.heycast/`.
`config.json` there is optional, read at launch and never written by the app; "Edit Config…" seeds a
template and opens it in your default editor. Edits take effect on the next
launch.

```json
{
  "keymaps": {
    "palette": "ctrl+space",
    "snippets": "ctrl+shift+space"
  },
  "snippetsDirectory": "~/Documents/heycast-snippets"
}
```

- `keymaps`: global shortcuts. See [docs/keymaps.md](docs/keymaps.md).
- `snippetsDirectory`: snippets folder. See
  [docs/snippets.md](docs/snippets.md#location).

## Snippets

A snippet is a Markdown file in the snippets folder: a `keyword` in the front
matter, then the text to paste. Set `type: script` or `script: <path>` to paste
a script's output instead. Full reference: [docs/snippets.md](docs/snippets.md).

```markdown
---
keyword: ;sig
name: Email signature
---

Best regards,
Nilambar Sharma
```

## Permissions

Heycast asks for one grant: **Accessibility**. It powers inline snippet
expansion, snippet pasting (Heycast types ⌘V for you) and moving or resizing
other apps' windows. Global hotkeys need no grant. The first-run wizard walks
through it; reopen it from "Permissions…".

No consent prompt? Move Heycast into `/Applications` and reopen it. Build and
signing caveats live in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 [Nilambar Sharma](https://www.nilambar.net)
