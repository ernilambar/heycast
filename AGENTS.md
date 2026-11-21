# AGENTS.md

## Overview

`heycast` is a menu-bar launcher for macOS: one shortcut opens apps, pastes
snippets and snaps windows. Native SwiftUI/AppKit accessory app (`LSUIElement`,
no Dock icon), zero third-party dependencies, local-only files. Core stack:
Swift 6, SwiftUI, AppKit, Carbon hotkeys, ServiceManagement; Swift Testing for
the suite.

## Setup

- macOS 14+ on Apple silicon (arm64 only; no Intel or universal build).
- A Swift 6 toolchain: Command Line Tools are enough, Xcode is not required.
  `make test` injects the Swift Testing macro plugin when Xcode is absent.
- No package dependencies, no build system beyond SwiftPM and `make`.
- Run `make dev-cert` once: a self-signed "Heycast Dev" identity keeps TCC
  grants across rebuilds. Without it builds are ad-hoc and re-prompt.

## Commands

- Run the app (debug build, install to `/Applications`, launch): `make run`
- Run all tests: `make test`
- Build the publishable bundle, zip and `SHA256SUMS`: `make bundle`
- Same build with the release signing gate: `make bundle-release`
- Quit a running instance: `make stop`
- Reset TCC answers and the wizard flag: `make reset-permissions`
- Regenerate the icon after editing `Resources/AppIcon.svg`: `./scripts/icon.sh`

## Conventions

- **4-space indentation** in Swift and shell. Keep the existing file layout:
  one concern per `Sources/Heycast/*.swift` file, listed in
  `CONTRIBUTING.md` (§ Layout).
- **No third-party dependencies.** Foundation, SwiftUI, AppKit, Carbon and the
  other system frameworks only. Adding a package needs a reason that survives
  the local-first, no-network promise.
- **Never make a network call.** No telemetry, analytics, crash reporting or
  remote config; that is the product promise in `docs/positioning.md`.
- **`Resources/Info.plist` is the single source of truth for the version** —
  both `CFBundleShortVersionString` and `CFBundleVersion`. Bump nothing else.
  `scripts/lib.sh` reads every piece of bundle metadata from it.
- **One build path:** `scripts/dev.sh` and `scripts/bundle.sh` own bundling and
  signing; `Makefile` targets stay thin wrappers. Do not add a second
  assembly/signing path.
- **Accessibility is the only permission.** Request it lazily, at first
  snippet or window use, never at launch. Do not add TCC prompts without a
  feature that genuinely needs them.
- **Shortcut actions are flat dotted strings** (`window.left`) and are
  declared as `KeymapAction` cases with an optional `defaultShortcut`. Give new
  commands `defaultShortcut: nil` until the combination is safe to claim; never
  take a combination macOS owns (`SystemShortcuts` lists them).
- **Config changes apply immediately** — writers (`SettingsModel`) update
  `config.json` atomically and the app re-registers in place. No
  relaunch-to-apply behavior.
- **Releases must never be ad-hoc signed.** `scripts/bundle.sh --release`
  signs with the "Heycast" identity or fails, and the designated requirement
  must equal `Resources/release-identity.txt`; a mismatch revokes every user's
  Accessibility grant. Never commit `*.p12`, `*.pem` or keychain files.
- **Keep `CHANGELOG.md` current with [flatlog](https://github.com/ernilambar/flatlog)**
  — `npx @nilambar/flatlog bullet "Added: ..."` per user-facing change,
  `npx @nilambar/flatlog release <version>` when tagging. Prefixes: `Added:`,
  `Changed:`, `Fixed:`.
- **Docs split:** `README.md` is user-facing, `CONTRIBUTING.md` is the
  developer/architecture reference, `docs/*.md` are feature references, and
  `docs/positioning.md` owns the one-sentence description — reuse it verbatim.
- **Tests cover pure logic only.** Panel, event tap, hotkey registration and
  TCC code are not unit-tested; verify them by running the app.

## Quality Gate

Before declaring a task complete, run in order and confirm each exits 0:

1. `make test` — full Swift Testing suite
2. `npx @nilambar/flatlog validate` — changelog structure (see `CHANGELOG.md`)
3. `make bundle` — release build, arm64 check, signing, zip and SHA256SUMS

For UI or behavior changes, also launch the built app and exercise the changed
path before finishing.
