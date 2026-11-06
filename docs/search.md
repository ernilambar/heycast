# Search

## Index

- `.app` bundles under `/Applications`, `/System/Applications` and
  `~/Applications`, including symlinked bundles such as Safari.
- Snippets from the snippets folder. See [snippets.md](snippets.md).
- Every palette open rescans the install roots in the background, so an app
  installed while Heycast runs appears on the next open. Opens that arrive
  during a scan collapse into one follow-up scan.
- Icons are cached per bundle, so a rescan does not re-render the list.

## Ranking

- Applications use name tiers, best first: exact, prefix, acronym,
  word-prefix, substring, subsequence. Usage breaks ties inside a tier.
- A snippet matches only when the query is exactly its keyword,
  case-sensitive. Its title is display-only; there is no fuzzy matching.
- Invalid snippet files appear after the results in the snippets scope, with
  the validation reason, and `⌘↩` reveals them in Finder.
- Empty query: frequently and recently launched apps first, then the rest
  alphabetically, then snippets by keyword, then invalid files by filename,
  then built-in commands by name.
- The panel grows from one to seven visible rows, then scrolls.

## Commands

Built-in commands are ordinary rows in the all scope. Type their name; there is
no prefix, `>` grammar or separate mode.

| Command | Does |
|---|---|
| `Sleep` | Sleeps the Mac (runs `/usr/bin/pmset sleepnow`) |
| `Open Permissions` | Opens the Accessibility setup window |
| `Open Config` | Opens `config.json` in the default editor |

- Commands are matched by name with the same tiers as applications.
- They do not appear in the snippets scope and have no global shortcut.
- **Lock Screen is not offered.** macOS 26 removed `CGSession`, and the
  remaining mechanisms need either a private API or an Automation grant, which
  would break the no-new-permission rule.
- Window actions stay on their hotkeys and in the Window menu; they are not
  duplicated as palette rows.

## Row actions

| Keys | Action |
|---|---|
| `⌘↩` | Reveal the selected app or snippet file in Finder |
| `⌥⌘C` | Copy its path |
| `⌥⌘B` | Copy an app's bundle identifier, when it has one |

The footer lists only the actions that work for the selected row.

## Usage history

- Stored locally in
  `~/Library/Application Support/net.nilambar.heycast/usage.json`.
- Scores damp raw launch counts logarithmically and halve every 30 days without
  a launch.
- Capped at the 200 most recently used apps.
