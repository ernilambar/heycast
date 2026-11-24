# AGENTS.md

## Overview

`heycast` is a menu-bar launcher for macOS: one shortcut opens apps, pastes
snippets and snaps windows. Native SwiftUI/AppKit accessory app (`LSUIElement`,
no Dock icon), local-only files. Core stack: Swift 6, SwiftUI, AppKit, Carbon
hotkeys, ServiceManagement; Swift Testing for the suite.

## Setup

- macOS 15+ on Apple silicon (arm64 only; no Intel or universal build).
- A Swift 6 toolchain: Command Line Tools are enough, Xcode is not required.
  `make test` injects the Swift Testing macro plugin when Xcode is absent.
- No package dependencies, no build system beyond SwiftPM and `make`.
- Run `make dev-cert` once: a self-signed "Heycast Dev" identity keeps TCC
  grants across rebuilds. Without it builds are ad-hoc and re-prompt.
- Published builds use a separate "Heycast" identity from `make release-cert`;
  only CI and release machines have it. Local work never needs it.

## Commands

| Command | Effect |
|---|---|
| `make run` | debug build, install `/Applications/Heycast Dev.app`, quit running copies, launch |
| `make test` | full Swift Testing suite; `make test FILTER=KeymapTests` runs one suite |
| `make bundle` | release build, arm64 check, bundle and zip under `dist/` |
| `make bundle-release` | the same build with the release signing gate; requires "Heycast" |
| `make stop` | quit a running instance |
| `make dev-cert` | one-time "Heycast Dev" identity for local TCC stability |
| `make release-cert` | one-time "Heycast" release identity; CI and release machines only |
| `make reset-permissions` | **destructive**; see [Safety](#safety) |
| `make clean` | remove `.build/` and `dist/` |

`make run` quits *every* running copy, release included, because only one
process can hold the global shortcuts. Local bundles are named `Heycast Dev`
with identifier `net.nilambar.heycast.dev`; do not look for `Heycast.app`.
`make bundle` uses the dev identity when present and falls back to ad-hoc with
a warning; it overwrites `dist/` first. `make bundle-release` never falls back.

## Non-negotiables

- **The shipped app makes no network calls at runtime.** No telemetry,
  analytics, crash reporting or remote config; that is the product promise in
  `docs/positioning.md`. Dev tooling (`npx`, `brew`) is exempt.
- **No third-party dependencies.** Foundation, SwiftUI, AppKit, Carbon and the
  other system frameworks only. Adding a package needs a reason that survives
  the local-first, no-network promise.
- **Accessibility is the only permission.** Request it lazily, at first
  snippet or window use, never at launch. Do not add TCC prompts without a
  feature that genuinely needs them.
- **Config changes apply immediately.** Writers (`SettingsModel`) update
  `config.json` atomically and the app re-registers in place. No
  relaunch-to-apply behavior.
- **Shortcut actions are flat dotted strings** (`window.left`), declared as
  `KeymapAction` cases with an optional `defaultShortcut`. New commands get
  `defaultShortcut: nil` until the combination is safe to claim; never take a
  combination macOS owns (`SystemShortcuts` lists them). An empty string in
  `keymaps` disables an action.
- **`Resources/Info.plist` is the single source of truth for the version** —
  both `CFBundleShortVersionString` and `CFBundleVersion`. Bump both keys and
  nothing else. A release tag `vX.Y.Z` must equal
  `CFBundleShortVersionString`, and `CHANGELOG.md` must validate for it; see
  `CONTRIBUTING.md` § Releasing. `scripts/lib.sh` reads every piece of bundle
  metadata from it.
- **One build path:** `scripts/dev.sh` and `scripts/bundle.sh` own bundling and
  signing; `Makefile` targets stay thin wrappers. Do not add a second
  assembly/signing path.
- **Releases must never be ad-hoc signed.** `scripts/bundle.sh --release`
  signs with the "Heycast" identity or fails, and the designated requirement
  must equal `Resources/release-identity.txt`; a mismatch revokes every user's
  Accessibility grant. Never commit `*.p12`, `*.pem` or keychain files.
- **Never hand-edit generated files.** `Resources/AppIcon.icns` comes from
  `Resources/AppIcon.svg` via `./scripts/icon.sh`; edit the SVG and rerun the
  script. `dist/`, `.build/` and signing material stay untracked.
- **4-space indentation** in Swift and shell. Keep one concern per
  `Sources/Heycast/*.swift` file; the authoritative map is `CONTRIBUTING.md`
  § Layout.

## Where things live

| Path | Ownership |
|---|---|
| `HeycastApp.swift`, `AppDelegate.swift` | entry point, status bar, panel lifecycle, action dispatch |
| `AppConfig.swift`, `Keymap.swift` | `config.json`, path resolution, keymap actions and defaults |
| `HotKey.swift`, `HotKeyController.swift` | shortcut parsing, Carbon registration |
| `PaletteController.swift`, `PaletteView.swift`, `PaletteSearch.swift` | palette panel, results, ranking |
| `Snippet*.swift` | front matter, placeholders, typed expansion, scripts, paste |
| `WindowManager.swift`, `WindowAction.swift` | window snapping and undo |
| `SettingsModel.swift`, `Permission*.swift` | settings writes, TCC status and wizard |
| `SupportDirectory.swift` | the single Application Support folder |
| `Tests/HeycastTests/` | pure-logic suites only; no UI-test target |

`config.json` has two keys: `keymaps` (flat action → shortcut, `""` disables)
and `snippetsDirectory` (optional; absent means the default folder).

## Recipes

**New shortcut command.** Add a `KeymapAction` case in `Keymap.swift` with
`defaultShortcut: nil` (and `menuTitle` if it belongs in the menu), handle it
in `AppDelegate.perform(_:toggling:)`, then update `docs/keymaps.md` and
`CHANGELOG.md`. The config shape does not change.

**New or changed user-facing feature.** Update the matching reference:
shortcuts → `docs/keymaps.md`; snippets → `docs/snippets.md`; ranking →
`docs/search.md`; install and usage → `README.md`; the one-sentence
description → `docs/positioning.md` (reuse it verbatim). Architecture, build
and signing details go to `CONTRIBUTING.md`, not `README.md`.

**Config-format change.** Dev and release builds share
`~/Library/Application Support/net.nilambar.heycast/` (`SupportDirectory`
hardcodes the identifier), so back it up first:
`cp -R "$HOME/Library/Application Support/net.nilambar.heycast" ~/heycast-backup`.

**Changelog.** Every user-facing change gets a flat bullet:
`npx --yes @nilambar/flatlog@2 bullet "Added: ..."`. Prefixes: `Added:`,
`Changed:`, `Fixed:`. A release promotes the unreleased block with
`npx --yes @nilambar/flatlog@2 release <version>`, validates it with
`... validate <version>`, and reopens a block with `... next` afterwards.

## Quality Gate

Before declaring a task complete, run the local gate in order and confirm each
exits 0:

1. `make test` — full Swift Testing suite (`make test FILTER=KeymapTests` for
   one suite; the Makefile injects the macro plugin when Xcode is absent)
2. `npx --yes @nilambar/flatlog@2 validate` — changelog structure (see
   `CHANGELOG.md`)
3. `make bundle` — release build, arm64 check, dev signing, zip and SHA256SUMS

The release gate is `make bundle-release`: the "Heycast" identity is required,
the designated requirement must match, and it runs in CI
(`.github/workflows/release.yml`). Do not expect it to pass on a machine
without the release identity; `make bundle` is the local check.

For UI or behavior changes, also `make run` and exercise the changed path:
`⌥Space` palette, `⌥⇧Space` snippets, menu-bar right-click, Settings and the
Permissions wizard. Panel, event tap, hotkey registration and TCC code have no
unit tests.

## Safety

- `make reset-permissions` is destructive: it runs `tccutil reset All` for the
  release identifier as well as `.dev`, and clears `setup.wizard.shown`.
  Never run it unless the user asked. To clean a dev install only:
  `tccutil reset All net.nilambar.heycast.dev` and
  `defaults delete net.nilambar.heycast.dev`.
- `make run` writes to `/Applications` and quits every running copy;
  `make bundle` overwrites `dist/`. Confirm before running either when the
  user may be using the app.
- Untrusted branches: `make` executes that branch's `scripts/` with your login
  keychain unlocked. Review `scripts/`, `Makefile` and `Package.swift` before
  running any make target from a PR branch. See `CONTRIBUTING.md` § Testing a
  pull request.

## Maintenance

Update this file whenever a command, release step, doc reference or test
category changes. `CONTRIBUTING.md` is the developer reference: keep
project-wide rules here and link there instead of copying them.
