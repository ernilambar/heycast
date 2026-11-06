# Contributing to heycast

Developer notes: build, test, layout, CI and the system-level details that only
matter while developing. For what the app does, see [README.md](README.md); for
the one-sentence positioning and the scope it rules out, see
[docs/positioning.md](docs/positioning.md).

## Requirements

- macOS 14+
- Swift 6 toolchain (Command Line Tools are enough; Xcode is not required)

## Build & run

```sh
make run               # debug build, install to /Applications, launch
make test              # unit tests (Swift Testing)
make bundle            # release .app, -macos-arm64.zip and SHA256SUMS under dist/
make bundle-release    # the same bundle, signing with the release identity only
make stop              # quit a running instance
make reset-permissions # clear TCC answers + the setup-complete flag
make dev-cert          # one-time: stable signing identity so grants survive rebuilds
make release-cert      # one-time: the "Heycast" identity that signs every release
make clean
```

Both scripts build only `darwin/arm64` and refuse to run on other hosts.

`./scripts/dev.sh --release` installs a release build the same way.

The app is an accessory (`LSUIElement`) app: no Dock icon, one status-bar item.
Its icon is the H monogram drawn as a template image (`StatusBarIcon.swift`), so
the system tints it black or white for the current menu-bar appearance instead
of showing the colored app icon.
SwiftUI content is hosted in a borderless floating `NSPanel` that toggles from
the status-bar item, the palette hotkey (`⌘Space`), the snippets-only hotkey
(`⌥Space`) or the menu-bar menu.

## Panel

The panel is transparent and borderless, 620 points wide and 157–385 points
tall depending on the result count, centered on the screen under the pointer
with its top edge offset 20% from the top. It is `nonactivatingPanel` +
`canBecomeKey`, so it can take keyboard focus from the launcher.

## Keymaps

Global shortcuts are declared by `KeymapAction` in `Keymap.swift`, which owns
the action name used in `config.json`, its optional default shortcut and its
menu title. `AppConfig.resolvedKeymap()` resolves configured bindings, rejects
invalid and duplicate combinations, and yields the `Keymap` that
`AppDelegate` registers through one `HotKeyController` per action.
`AppDelegate.applyConfig()` repeats that resolution whenever `config.json`
changes (the settings window writes it atomically, and a directory watcher
catches hand edits), re-registering only when the keymap actually differs.
`SystemShortcuts` lists the combinations macOS owns; the settings window shows
those conflicts and any `RegisterEventHotKey` failure with a Change action.

To add a command (window management, for example): add a `KeymapAction` case,
give it a `defaultShortcut` or leave it `nil` to require an explicit bind, set
a `menuTitle` if it belongs in the status-bar menu, and handle it in
`AppDelegate.perform(_:toggling:)`. The config shape does not change.

Action names stay flat strings. Group related commands with a dot namespace
rather than nesting objects, so resolution remains a single
`[String: String]` pass:

```json
{
  "keymaps": {
    "palette": "alt+space",
    "snippets": "alt+shift+space",
    "window.left": "ctrl+alt+left",
    "window.right": "ctrl+alt+right",
    "window.top": "ctrl+alt+up",
    "window.bottom": "ctrl+alt+down",
    "window.maximize": "ctrl+alt+return",
    "window.center": "ctrl+alt+c"
  }
}
```

Give new commands `defaultShortcut: nil` until their defaults are safe to
claim globally; an unbound action stays disabled and does not register a
hotkey.

## Permissions while developing

The app needs one grant today: **Accessibility**, used for inline snippet
expansion and for typing ⌘V into the app in front after the palette copies a
snippet body.

The setup window does not open at launch. It opens the first time a snippet or
window command needs Accessibility, and from "Permissions…" in the menu-bar
item; the setup-complete flag is written only when the wizard is finished.

- The global hotkeys need no grant: Carbon `RegisterEventHotKey` is delivered
  by the window server.
- Microphone and Speech Recognition are not asked for because no audio exists.
  Add them with the voice feature — and Speech only if transcription uses
  Apple's `SFSpeechRecognizer` rather than a remote model.
- Input Monitoring is not needed: typed-keyword expansion uses a keyboard
  event tap that can modify events, which Accessibility authorizes. Only a
  listen-only tap would need Input Monitoring.
- Screen Recording and Full Disk Access are not asked for; nothing reads the
  screen or protected files such as Mail, Messages and Safari.
- System prompts only appear for a bundled, `/Applications`-installed app;
  `swift run` does not get them.
- Ad-hoc signatures change on every build, and macOS keys TCC entries to the
  signature, so rebuilds re-prompt. Run `make dev-cert` once: it creates a
  self-signed "Heycast Dev" identity that the scripts use automatically, so
  grants survive `make run`. `HEYCAST_SIGN_IDENTITY` overrides the identity.
  The dev identity is for local builds only; releases use "Heycast" (see
  [Release signing](#release-signing)).
  After creating it (or switching identity), run `make reset-permissions` and
  grant again: an existing grant still points at the old signature, so it
  shows ON in System Settings but does not apply.
- Screen Recording and Full Disk Access only take effect after relaunching.
  macOS offers "Quit & Reopen" for screen recording; full disk access is
  granted by adding the app with `+` in the pane.
- `make reset-permissions` runs `tccutil reset All <bundle id>` and forgets
  the setup-complete flag.

## Icon

`Resources/AppIcon.svg` is the 1024x1024 source and `Resources/AppIcon.icns` is
generated from it and committed, so a build needs no renderer.
`CFBundleIconFile` in the plist names it and `assemble_bundle` copies it into
`Contents/Resources`. After editing the SVG, run `./scripts/icon.sh` (
`sips` rasterizes the SVG, `iconutil` packs every size) and rebuild.

## Release signing

Two identities exist, and they never mix:

| Identity | Used by | Created by |
| --- | --- | --- |
| `Heycast Dev` | `make run`, `make bundle` on a developer machine | `make dev-cert` |
| `Heycast` | every published build, CI only | `make release-cert` |

`Heycast` is a self-signed certificate with a ten-year validity and the
code-signing EKU. macOS keys Privacy & Security grants to the signature, so
this one certificate is the TCC key for every installed copy: rotating it
changes the designated requirement and silently resets Accessibility for all
users at the next `brew upgrade`. Keep one identity for the life of the 0.x
line.

### The designated requirement

`Resources/release-identity.txt` is the requirement the identity produces:

```text
identifier "net.nilambar.heycast" and certificate leaf = H"…"
```

It is committed, and `scripts/bundle.sh --release` fails when a build's
requirement differs from it. That is deliberately a build failure, not a
warning: a mismatch means the certificate was recreated, and shipping it
would revoke every existing grant. Only rewrite the file with
`./scripts/release-cert.sh --record` when the rotation is intentional, and
say so in the release notes so users know to grant Accessibility again.

### Creating the identity (once)

```sh
make release-cert     # creates "Heycast", exports .p12, records the requirement
```

The .p12 and its password go to `~/.heycast/release/` (`chmod 600`), never into
the repository; `.gitignore` blocks `*.p12`, `*.pem` and `*.keychain*` anyway.

**Back that folder up somewhere that outlives this Mac** — a password manager,
an encrypted disk, or both. If the keychain is wiped and the backup is gone,
the certificate has to be recreated, and the next release resets Accessibility
for everyone.

Then store the three secrets on the `release` environment of the GitHub
repository (it has a required reviewer, so publishing waits for a human):

```sh
base64 -i ~/.heycast/release/heycast.p12 | gh secret set HEYCAST_P12 --env release
gh secret set HEYCAST_P12_PASSWORD --env release < ~/.heycast/release/password.txt
gh secret set KEYCHAIN_PASSWORD --env release < ~/.heycast/release/keychain-password.txt
```

To sign on a second machine, import the backup instead of recreating it:

```sh
security import ~/.heycast/release/heycast.p12 -k login.keychain-db \
  -P "$(cat ~/.heycast/release/password.txt)" -T /usr/bin/codesign
```

### Checking a build

```sh
make bundle-release
codesign -d -r- dist/Heycast.app    # must equal Resources/release-identity.txt
codesign -dv dist/Heycast.app       # must say Authority=Heycast
```

The manual **signing** job in `.github/workflows/ci.yml` does the same thing in
CI and builds twice to prove the requirement reproduces. Run it from the
Actions tab (`workflow_dispatch`) before a tag, or after touching anything that
signs.

`spctl` rejects the app by design because it is not notarized. Do not gate on
it; the cask clears the quarantine flag instead.

## Releasing

Cadence is per phase, not per calendar: a release ships when a phase in the
plan is done and has met its acceptance criteria. Versions follow semantic
versioning, stay `0.x` through the planned phases, and each tag needs a
validated `CHANGELOG.md` entry. There is no beta channel and no in-app updater.

`CHANGELOG.md` uses [flatlog](https://github.com/ernilambar/flatlog): flat
bullets prefixed `Added:`, `Changed:` or `Fixed:`, newest release first, with
an optional topmost `## X.X.X - YYYY-MM-DD` placeholder for work in progress.
Run `npx @nilambar/flatlog validate` before committing changelog edits.

`Resources/Info.plist` owns the version: `CFBundleShortVersionString` is the
release version and `CFBundleVersion` its build number. Nothing else stores it,
so a bump is a single-file change.

1. Bump both keys in `Resources/Info.plist`.
2. Promote the unreleased block with
   `npx @nilambar/flatlog release X.Y.Z` (skip this when the version header
   already exists), then check it with `npx @nilambar/flatlog validate X.Y.Z`.
3. Run `make test && make bundle` and check `dist/` by hand. To test the exact
   CI path, run the signing job from the Actions tab first.
4. Commit, then tag and push: `git tag -a vX.Y.Z -m vX.Y.Z && git push origin main vX.Y.Z`.
5. After the release, run `npx @nilambar/flatlog next` to open the next
   unreleased block.

Pushing the tag runs `.github/workflows/release.yml`. It waits for approval on
the `release` environment, then rejects a tag whose version differs from the
plist, rejects a tag whose changelog does not validate for that version, runs
the tests, imports the `Heycast` identity from the environment secrets, builds
with signing enforced, checks the designated requirement, and publishes
`Heycast-macos-arm64.zip` and `SHA256SUMS` on the GitHub release. A missing or
mismatched certificate fails the job; the release path never falls back to
ad-hoc signing.

The tag carries a `v` prefix; the plist keeps the bare version. The release
title is the tag alone, e.g. `v0.1.0`, and the body is `CFBundleName` plus the
tag, linking to `CHANGELOG.md` for the details.

## Layout

```
Sources/Heycast/
  HeycastApp.swift       @main entry, accessory activation policy
  AppDelegate.swift      status-bar item, config menu, panel lifecycle
  SupportDirectory.swift Application Support namespace, file locations
  AppConfig.swift        config.json loading, keymap resolution, snippets path
  Keymap.swift           keymap actions, defaults, resolved shortcut map
  HotKey.swift           hotkey parsing, display, serialization and menu key equivalent
  SystemShortcuts.swift  shortcuts macOS already owns, checked by the settings window
  StatusBarIcon.swift    template H mark for the menu-bar item
  PaletteController.swift NSPanel configuration, placement, resize, row actions, commands
  PaletteView.swift      SwiftUI palette content, scope, results list + model
  ApplicationCatalog.swift  installed app scan and match ranking
  Snippet.swift          snippet front matter, scan/validation, placeholders
  SnippetExpander.swift  typed-keyword matching and expansion event tap
  SyntheticKeyboard.swift synthesized backspaces and ⌘V for snippets
  PaletteSearch.swift    merged app, snippet and command ranking; palette items
  UsageStore.swift       persisted launch counts and recency, usage scoring
  HotKeyController.swift global hotkeys via Carbon RegisterEventHotKey
  LoginItem.swift        Launch at Login through SMAppService
  SettingsModel.swift    settings rows, hotkey recorder, atomic config writes
  SettingsView.swift     settings window content
  SettingsController.swift  settings window lifecycle
  Clipboard.swift        pasteboard snapshot restored after a snippet paste
  Permission.swift       TCC permissions: status checks, requests, panes
  PermissionWizardModel.swift  wizard steps, refresh on app activation
  PermissionWizardView.swift   wizard pages + summary
  PermissionWizardController.swift  setup window lifecycle
  AboutView.swift        About panel content and version formatting
  AboutController.swift  About window lifecycle
Resources/Info.plist     LSUIElement, bundle metadata, TCC usage strings
Resources/release-identity.txt  designated requirement every release must match
Resources/AppIcon.svg    app icon source, 1024x1024
Resources/AppIcon.icns   generated icon bundled as Contents/Resources/AppIcon.icns
scripts/icon.sh          regenerate AppIcon.icns from AppIcon.svg
scripts/lib.sh           plist metadata, signing identity, bundle assembly, shared by the scripts
scripts/dev.sh           debug/release build, install to /Applications, relaunch
scripts/bundle.sh        release gate, bundle, zip archive, SHA256SUMS
scripts/dev-cert.sh      create the local "Heycast Dev" signing identity
scripts/release-cert.sh  create/export the "Heycast" release identity
scripts/ci-import-identity.sh  import the release identity from CI secrets
Makefile                 thin wrappers around the scripts
Tests/HeycastTests/      Swift Testing suites for the pure logic
.github/workflows/ci.yml test workflow, macOS runner, manual signing gate
.github/workflows/release.yml  tag-triggered release, publishes the bundle
docs/positioning.md      the one-sentence positioning and what it rules out
CHANGELOG.md             release notes; the only source for them
LICENSE                  MIT
```

## Tests

`make test` runs the Swift Testing suites in `Tests/HeycastTests/`: search
ranking, snippet parsing and keyword matching, merged palette ranking, usage
scoring and persistence, config path resolution and keymap resolution, and
launch history pruning. These cover the pure logic; the panel, event tap,
hotkey registration and TCC code are not unit-tested because they need real
UI/system state.

The test target depends on the executable target and imports it with
`@testable`, so the app needs no separate library target. Swift Testing ships
with the Swift 6 Command Line Tools, but SwiftPM only injects its macro plugin
in an Xcode toolchain layout, so `make test` passes the plugin path itself
when Xcode is absent.

CI (`.github/workflows/ci.yml`) runs the suite on `macos-15` for pushes to
`main` and every pull request. `.github/workflows/release.yml` runs it again on
a version tag and publishes the release.

## Next

- More result sources: windows, files, system settings and commands alongside
  applications
