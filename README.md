# heycast

A macOS launcher palette. Press `⌃Space` anywhere, type a few letters, hit
`↩`, and the app you meant opens. Press `⌃⇧Space` to search snippets only.
Heycast lives in the menu bar — no Dock icon, no window to manage.

## Install

- macOS 14 or later, Apple silicon.
- Requires build and install from source: see [CONTRIBUTING.md](CONTRIBUTING.md).

After installing, Heycast starts in the menu bar. There is nothing to launch
from Launchpad or Finder.

## Use

- `⌃Space` toggles the palette from any app. Change it with
  `keymaps.palette` in `config.json`.
- `⌃⇧Space` opens the palette with snippets only. Change it with
  `keymaps.snippets`.
- Click the menu-bar item to toggle the full palette.
- Right-click the menu-bar item for "Open Palette", "Open Snippets",
  "Edit Config…", "Permissions…" and "Quit Heycast".
- `↑`/`↓` moves the selection, `↩` launches the selected app or pastes the
  selected snippet, clicking a row does the same, `esc` or focusing another app
  closes the palette.
- Typing a snippet keyword in any app expands it in place; this needs
  Accessibility.

## Search

The palette indexes `.app` bundles under `/Applications`,
`/System/Applications` and `~/Applications`, including symlinked bundles such
as Safari, alongside the snippets folder (see [Snippets](#snippets)). The app
scan runs in the background the first time the palette opens.

- Type to filter by name: exact, prefix, acronym, word-prefix, substring and
  subsequence matches rank in that order; usage breaks ties inside a tier.
- With no query, frequently and recently launched apps come first, then the
  rest alphabetically.
- Launch counts and recency are kept locally in
  `~/Library/Application Support/net.nilambar.heycast/usage.json`. Scores damp
  raw counts logarithmically and halve every 30 days without a launch; history
  is capped at the 200 most recently used apps.
- The panel grows from one to seven visible rows, then scrolls.
- Apps installed after Heycast starts appear the next time it is launched.

## Config

All app files live in `~/Library/Application Support/net.nilambar.heycast/`.
`config.json` there is optional, read at launch and never written by the app;
"Edit Config…" seeds a template and opens it in your default editor.

```json
{
  "keymaps": {
    "palette": "ctrl+space",
    "snippets": "ctrl+shift+space"
  },
  "snippetsDirectory": "~/Documents/heycast-snippets"
}
```

- `keymaps` maps command names to global shortcuts. The built-in actions are
  `palette` (the full apps-and-snippets palette) and `snippets` (snippets
  only). Future actions such as window management use the same object; unknown
  names are logged and ignored.
- Join modifiers and one key with `+`, for example `cmd+shift+k`, `alt+space`
  or `ctrl+f1`. Modifiers are `ctrl`/`control`, `alt`/`opt`/`option`,
  `cmd`/`command` and `shift`; at least one of control, option or command is
  required. Keys are letters, digits, `space`, `return`, `tab`, `escape`,
  arrows, `home`, `end`, `pageup`, `pagedown`, punctuation marks and
  `f1`…`f20` (`delete`, `backspace` and `forwarddelete` included).
- Missing actions use their built-in default: `palette` is `ctrl+space` and
  `snippets` is `ctrl+shift+space`. Set a value to `""` to disable that action.
- An invalid shortcut is logged and falls back to the action's default. A
  duplicate shortcut is logged and the first action wins (`palette` before
  `snippets`). Registration can also fail when another app or a system
  shortcut owns the combination; that is logged too.
- The snippets folder defaults to `snippets/` beside `usage.json`; a configured
  path replaces it entirely and is created if missing.
- `~` expands to your home directory; relative paths resolve against the config
  file's own directory.
- A path that cannot be created is logged and ignored in favour of the default.
- Edits take effect on the next launch.
- A symlinked `snippets/` folder works too.

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

Heycast asks for one grant: **Accessibility**, used for inline snippet
expansion and for pasting snippets into the app in front by typing ⌘V for you.
The first-run wizard explains it, shows the real system state, raises the
consent prompt and links to the matching System Settings pane. Reopen it any
time from "Permissions…".

The global hotkeys (`⌃Space` and `⌃⇧Space` by default) need no grant. Heycast
does not ask for Microphone, Speech Recognition, Input Monitoring, Screen
Recording or Full Disk Access, and does not read your screen or protected
files.

If no consent prompt appears, the standard cause is running an app from
outside `/Applications`; move Heycast into `/Applications` and reopen it. Build
and signing caveats live in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 [Nilambar Sharma](https://www.nilambar.net)
