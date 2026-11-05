# heycast

A macOS launcher palette. Press `⌥Space` anywhere, type a few letters, hit
`↩`, and the app you meant opens. Heycast lives in the menu bar — no Dock icon,
no window to manage.

## Install

- macOS 14 or later, Apple silicon.
- Requires build and install from source: see [CONTRIBUTING.md](CONTRIBUTING.md).

After installing, Heycast starts in the menu bar. There is nothing to launch
from Launchpad or Finder.

## Use

- `⌥Space` toggles the palette from any app.
- Click the menu-bar item to toggle it.
- Right-click the menu-bar item for "Open Palette", "Edit Config…",
  "Permissions…" and "Quit Heycast".
- `↑`/`↓` moves the selection, `↩` launches the selected app or pastes the
  selected snippet, clicking a row does the same, `esc` or focusing another app
  closes the palette.

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
  "snippetsDirectory": "~/Documents/heycast-snippets"
}
```

- The snippets folder defaults to `snippets/` beside `usage.json`; a configured
  path replaces it entirely and is created if missing.
- `~` expands to your home directory; relative paths resolve against the config
  file's own directory.
- A path that cannot be created is logged and ignored in favour of the default.
- Edits take effect on the next launch.
- A symlinked `snippets/` folder works too.

## Snippets

A snippet is a Markdown file in the snippets folder. The front matter gives it
a keyword and a title; the body is the text that gets pasted.

```markdown
---
keyword: ;sig
name: Email signature
---

Best regards,
Nilambar
```

- `keyword` is required and is what the palette matches on; `name` is optional
  and defaults to the keyword.
- Files are re-read every time the palette opens, so an edit shows up at once.
- Files without front matter, without a keyword, or with an empty body are
  skipped and logged.
- Snippets are found by keyword and by name with the same ranking as apps; with
  an empty query they follow the applications, ordered by keyword.
- Pasting types ⌘V into the app that was frontmost before the palette opened,
  which is what needs Accessibility. Without the grant the text is still copied
  to the clipboard.

## Permissions

Heycast asks for one grant: **Accessibility**, used by snippets to paste into
the app in front by typing ⌘V for you. The first-run wizard explains it,
shows the real system state, raises the consent prompt and links to the
matching System Settings pane. Reopen it any time from "Permissions…".

The `⌥Space` hotkey needs no grant. Heycast does not ask for Microphone,
Speech Recognition, Input Monitoring, Screen Recording or Full Disk Access, and
does not read your screen or protected files.

If no consent prompt appears, the standard cause is running an app from
outside `/Applications`; move Heycast into `/Applications` and reopen it. Build
and signing caveats live in [CONTRIBUTING.md](CONTRIBUTING.md).

## Planned

- More result sources: windows, files, system settings and commands alongside
  applications.
