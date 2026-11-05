# Contributing to heycast

Developer notes: build, test, layout, CI and the system-level details that only
matter while developing. For what the app does, see [README.md](README.md).

## Requirements

- macOS 14+
- Swift 6 toolchain (Command Line Tools are enough; Xcode is not required)

## Build & run

```sh
make run               # debug build, install to /Applications, launch
make test              # unit tests (Swift Testing)
make bundle            # release .app, -macos-arm64.zip and SHA256SUMS under dist/
make stop              # quit a running instance
make reset-permissions # clear TCC answers + the first-run flag
make dev-cert          # one-time: stable signing identity so grants survive rebuilds
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
    "palette": "cmd+space",
    "snippets": "alt+space",
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
  After creating it (or switching identity), run `make reset-permissions` and
  grant again: an existing grant still points at the old signature, so it
  shows ON in System Settings but does not apply.
- Screen Recording and Full Disk Access only take effect after relaunching.
  macOS offers "Quit & Reopen" for screen recording; full disk access is
  granted by adding the app with `+` in the pane.
- `make reset-permissions` runs `tccutil reset All <bundle id>` and forgets
  the first-run flag.

## Icon

`Resources/AppIcon.svg` is the 1024x1024 source and `Resources/AppIcon.icns` is
generated from it and committed, so a build needs no renderer.
`CFBundleIconFile` in the plist names it and `assemble_bundle` copies it into
`Contents/Resources`. After editing the SVG, run `./scripts/icon.sh` (
`sips` rasterizes the SVG, `iconutil` packs every size) and rebuild.

## Releasing

`Resources/Info.plist` owns the version: `CFBundleShortVersionString` is the
release version and `CFBundleVersion` its build number. Nothing else stores it,
so a bump is a single-file change.

1. Bump both keys in `Resources/Info.plist`.
2. Add a `## [x.y.z] - YYYY-MM-DD` section to `CHANGELOG.md`.
3. Run `make test && make bundle` and check `dist/` by hand.
4. Commit, then tag and push: `git tag -a vX.Y.Z -m vX.Y.Z && git push origin main vX.Y.Z`.

Pushing the tag runs `.github/workflows/release.yml`. It rejects a tag whose
version differs from the plist, runs the tests, builds the bundle, and
publishes `Heycast-macos-arm64.zip` and `SHA256SUMS` on the GitHub release,
using that `CHANGELOG.md` section as the release notes. The tag carries a `v`
prefix; the plist keeps the bare version.

## Layout

```
Sources/Heycast/
  HeycastApp.swift       @main entry, accessory activation policy
  AppDelegate.swift      status-bar item, config menu, panel lifecycle
  SupportDirectory.swift Application Support namespace, file locations
  AppConfig.swift        config.json loading, keymap resolution, snippets path
  Keymap.swift           keymap actions, defaults, resolved shortcut map
  HotKey.swift           hotkey parsing, display and menu key equivalent
  StatusBarIcon.swift    template H mark for the menu-bar item
  PaletteController.swift NSPanel configuration, placement, resize, launching
  PaletteView.swift      SwiftUI palette content, scope, results list + model
  ApplicationCatalog.swift  installed app scan and match ranking
  Snippet.swift          snippet front matter, folder loading
  SnippetExpander.swift  typed-keyword matching and expansion event tap
  SyntheticKeyboard.swift synthesized backspaces and ⌘V for snippets
  PaletteSearch.swift    merged app + snippet ranking for the palette
  UsageStore.swift       persisted launch counts and recency, usage scoring
  HotKeyController.swift global hotkeys via Carbon RegisterEventHotKey
  Permission.swift       TCC permissions: status checks, requests, panes
  PermissionWizardModel.swift  wizard steps, refresh on app activation
  PermissionWizardView.swift   wizard pages + summary
  PermissionWizardController.swift  setup window lifecycle
  AboutView.swift        About panel content and version formatting
  AboutController.swift  About window lifecycle
Resources/Info.plist     LSUIElement, bundle metadata, TCC usage strings
Resources/AppIcon.svg    app icon source, 1024x1024
Resources/AppIcon.icns   generated icon bundled as Contents/Resources/AppIcon.icns
scripts/icon.sh          regenerate AppIcon.icns from AppIcon.svg
scripts/lib.sh           plist metadata + bundle assembly, shared by the scripts
scripts/dev.sh           debug/release build, install to /Applications, relaunch
scripts/bundle.sh        release gate, bundle, zip archive, SHA256SUMS
Makefile                 thin wrappers around the scripts
Tests/HeycastTests/      Swift Testing suites for the pure logic
.github/workflows/ci.yml test workflow, macOS runner
.github/workflows/release.yml  tag-triggered release, publishes the bundle
CHANGELOG.md             release notes, one section per version
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
