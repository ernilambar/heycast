# Snippets

A snippet is a Markdown file in the snippets folder: front matter, then body.

```markdown
---
keyword: ;sig
name: Email signature
---

Best regards,
Nilambar
```

## Location

- Default: `snippets/` beside `usage.json`.
- Override with `snippetsDirectory` in the config. `~` expands; a symlinked
  folder works.
- Flat folder: only top-level `.md` files load. Hidden files are ignored.
- Edits apply on the next palette open or folder change. No restart needed.

## Front matter

| Field | Required | Meaning |
|---|---|---|
| `keyword` | Yes | Trigger and palette match, e.g. `;sig` |
| `name` | No | Title in the palette. Defaults to `keyword` |
| `type` | No | `text` (default) or `script` |
| `script` | No | Path to an executable whose output is pasted. Overrides `type` and the body |

- One `key: value` per line. Matching quotes around a value are removed.
- Files without front matter, without `keyword`, with an unknown `type`, or
  with an empty body (except `script:` snippets) are skipped and logged.

## Body

- Everything after the closing `---`, pasted exactly as written: leading
  blank lines and the final newline included.
- A body that is only whitespace counts as empty.

## Using snippets

| Way | How |
|---|---|
| Inline | Type the keyword in any app. It is deleted and replaced with the text |
| Palette | `⌃Space` (everything) or `⌃⇧Space` (snippets only), select, `↩` |

- Matching is exact and case-sensitive.
- If one keyword is a prefix of another, the shorter one waits instead of
  stealing the longer trigger.
- ⌘/⌃/⌥ shortcuts, arrows, return, tab and escape reset the typed buffer.
- Pasting types ⌘V into the target app, so it overwrites the clipboard.
- Needs Accessibility. Without it, the palette still copies the text to the
  clipboard; inline expansion is off.

## Script snippets

The script's standard output is pasted instead of the body.

### Inline: `type: script`

The body is the script. The `#!` line picks the interpreter; without one it
runs with `/bin/zsh`. Leading blank lines before `#!` are ignored.

```markdown
---
keyword: ;today
name: Today
type: script
---
#!/usr/bin/env python3
import datetime
print(datetime.date.today().isoformat())
```

### External file: `script: <path>`

Runs an executable file; the body is ignored. `~` expands; a relative path
resolves against the snippets folder. The file needs `chmod +x` and a `#!`
line.

```markdown
---
keyword: ;ip
name: Public IP
script: ~/bin/public-ip.sh
---
```

`~/bin/public-ip.sh`:

```sh
#!/bin/sh
curl -fsS https://api.ipify.org
```

Make it executable once: `chmod +x ~/bin/public-ip.sh`.

Use inline for a few lines; use a file for anything you want to lint, test or
run from Terminal.

### Behavior

| Case | Result |
|---|---|
| Exit 0 with output | Output pasted, minus one trailing newline |
| Non-zero exit | Nothing pasted, beep, stderr logged |
| Empty output or non-UTF-8 | Nothing pasted, beep |
| Runs longer than 5 s | Killed, nothing pasted, beep |
| Inline trigger fails | Typed keyword stays in place |

- Runs in the background, so the keyboard never stalls.
- Reads the clipboard with `pbpaste`; it still holds what you copied, because
  the script runs before Heycast writes to it.
- Working directory is your home folder; stdin is empty.
- `PATH` comes from your login shell (`$SHELL -l`), so Homebrew tools resolve
  as in Terminal. `PATH` set only in `.zshrc` is not seen; set it in
  `.zprofile`.
- Script snippets show a terminal icon in the palette.

### Security

Typing a keyword runs code. Keep the snippets folder to files you wrote; do
not sync it with folders other people can write to.
