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
make clean
```

Both scripts build only `darwin/arm64` and refuse to run on other hosts.

`./scripts/dev.sh --release` installs a release build the same way.

The app is an accessory (`LSUIElement`) app: no Dock icon, one status-bar item.
SwiftUI content is hosted in a borderless floating `NSPanel` that toggles from
the status-bar item, the `⌥Space` hotkey or the menu-bar menu.

## Panel

The panel is transparent and borderless, 620 points wide and 157–385 points
tall depending on the result count, centered on the screen under the pointer
with its top edge offset 20% from the top. It is `nonactivatingPanel` +
`canBecomeKey`, so it can take keyboard focus from the launcher.

## Permissions while developing

The app needs one grant today: **Accessibility**, used by snippets to read the
focused text and type the expansion back in.

- The `⌥Space` hotkey needs no grant: Carbon `RegisterEventHotKey` is
  delivered by the window server.
- Microphone and Speech Recognition are not asked for because no audio exists.
  Add them with the voice feature — and Speech only if transcription uses
  Apple's `SFSpeechRecognizer` rather than a remote model.
- Input Monitoring is not needed: a keyword event tap that can modify events
  (snippets must swallow the trigger) is authorized by Accessibility. Only a
  listen-only tap would need it.
- Screen Recording and Full Disk Access are not asked for; nothing reads the
  screen or protected files such as Mail, Messages and Safari.
- System prompts only appear for a bundled, `/Applications`-installed app;
  `swift run` does not get them.
- Ad-hoc signatures change on every build, and macOS keys TCC entries to the
  signature, so rebuilds re-prompt. Export `HEYCAST_SIGN_IDENTITY` with a
  stable codesigning identity (e.g. a self-signed "Heycast Dev" cert) to keep
  grants across `make run`.
- Screen Recording and Full Disk Access only take effect after relaunching.
  macOS offers "Quit & Reopen" for screen recording; full disk access is
  granted by adding the app with `+` in the pane.
- `make reset-permissions` runs `tccutil reset All <bundle id>` and forgets
  the first-run flag.

## Layout

```
Sources/Heycast/
  HeycastApp.swift       @main entry, accessory activation policy
  AppDelegate.swift      status-bar item, config menu, panel lifecycle
  SupportDirectory.swift Application Support namespace, file locations
  AppConfig.swift        config.json loading and snippets path resolution
  PaletteController.swift NSPanel configuration, placement, resize, launching
  PaletteView.swift      SwiftUI palette content, results list + model
  ApplicationCatalog.swift  installed app scan and match ranking
  UsageStore.swift       persisted launch counts and recency, usage scoring
  HotKeyController.swift global ⌥Space via Carbon RegisterEventHotKey
  Permission.swift       TCC permissions: status checks, requests, panes
  PermissionWizardModel.swift  wizard steps, refresh on app activation
  PermissionWizardView.swift   wizard pages + summary
  PermissionWizardController.swift  setup window lifecycle
Resources/Info.plist     LSUIElement, bundle metadata, TCC usage strings
scripts/lib.sh           plist metadata + bundle assembly, shared by the scripts
scripts/dev.sh           debug/release build, install to /Applications, relaunch
scripts/bundle.sh        release gate, bundle, zip archive, SHA256SUMS
Makefile                 thin wrappers around the scripts
Tests/HeycastTests/      Swift Testing suites for the pure logic
.github/workflows/ci.yml test workflow, macOS runner
```

## Tests

`make test` runs the Swift Testing suites in `Tests/HeycastTests/`: search
ranking, usage scoring and persistence, config path resolution, and launch
history pruning. These cover the pure logic; the palette, panel, hotkey and
TCC code are not unit-tested because they need real UI/system state.

The test target depends on the executable target and imports it with
`@testable`, so the app needs no separate library target. Swift Testing ships
with the Swift 6 Command Line Tools, but SwiftPM only injects its macro plugin
in an Xcode toolchain layout, so `make test` passes the plugin path itself
when Xcode is absent.

CI (`.github/workflows/ci.yml`) runs the suite on `macos-15` for pushes to
`main` and every pull request.

## Next

- Snippets: keyword storage, keystroke matching and in-place expansion, all
  under the Accessibility grant
- More result sources: windows, files, system settings and commands alongside
  applications
