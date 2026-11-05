# heycast

A macOS palette app: SwiftUI content hosted in a borderless, floating
`NSPanel`. The status-bar app opens a launcher-style palette that searches
installed applications and launches the selected one.

## Requirements

- macOS 14+
- Swift 6 toolchain (Command Line Tools are enough; Xcode is not required)

## Build & run

```sh
make run               # debug build, install to /Applications, launch
make bundle            # release .app, -macos-arm64.zip and SHA256SUMS under dist/
make stop              # quit a running instance
make reset-permissions # clear TCC answers + the first-run flag
make clean
```

Both scripts build only `darwin/arm64` and refuse to run on other hosts.

`./scripts/dev.sh --release` installs a release build the same way.

The app is an accessory (`LSUIElement`) app: no Dock icon, one status-bar
item. Click it to open the palette.

- left-click the status-bar item to toggle it
- `⌥Space` toggles it globally, from any app (Carbon `RegisterEventHotKey`,
  no permission required)
- right-click it for "Open Palette" / "Edit Config…" / "Permissions…" /
  "Quit Heycast"
- `esc` or focusing another app closes the palette

## Applications

The palette indexes `.app` bundles under `/Applications`, `/System/Applications`
and `~/Applications`, including symlinked bundles such as Safari. The scan runs
in the background the first time the palette opens and is cached for the rest
of the process.

- type to filter by name; exact, prefix, acronym, word-prefix, substring and
  subsequence matches rank in that order, with usage breaking ties inside a
  tier
- with no query, frequently and recently launched apps come first, then the
  rest alphabetically
- launch counts and recency persist in
  `~/Library/Application Support/net.nilambar.heycast/usage.json`; the score
  damps raw counts logarithmically and halves every 30 days without a launch,
  and history is capped at the 200 most recently used apps
- `↑`/`↓` moves the selection, `↩` launches it
- clicking a row launches that app
- the panel grows from one to seven visible rows, then scrolls

Apps installed after Heycast starts show up the next time it is launched.

## Config

All app files live in `~/Library/Application Support/net.nilambar.heycast/`.
`config.json` there is optional, read at launch and never written by the app;
"Edit Config…" in the status-bar menu seeds a template and opens it in your
default editor.

```json
{
  "snippetsDirectory": "~/Dropbox/heycast-snippets"
}
```

- the snippets folder defaults to `snippets/` beside `usage.json`; a configured
  path replaces it entirely and is created if missing
- `~` expands to the home directory; relative paths resolve against the config
  file's own directory
- a path that cannot be created is logged and ignored in favour of the default
- editing the file takes effect on the next launch
- a symlinked `snippets/` folder works too, since links are resolved before
  reading and watching

## Permissions

heycast needs one grant today: **Accessibility**, used by snippets to read the
focused text and type the expansion back in. The first-run wizard explains it,
reports the real TCC state, triggers the consent prompt and deep-links to the
matching System Settings pane; reopen it any time from "Permissions…".

- The `⌥Space` hotkey needs no grant: Carbon `RegisterEventHotKey` is
  delivered by the window server.
- Microphone and Speech Recognition are not asked for because no audio code
  exists. Add them with the voice feature — and Speech only if transcription
  uses Apple's `SFSpeechRecognizer` rather than a remote model.
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
```

The panel is transparent and borderless, 620 points wide and 157–385 points
tall depending on the result count, centered on the screen under the pointer
with its top edge offset 20% from the top. It is `nonactivatingPanel` +
`canBecomeKey`, so it can take keyboard focus from the launcher.

## Next

- Snippets: keyword storage, keystroke matching and in-place expansion, all
  under the Accessibility grant
- More result sources: windows, files, system settings and commands alongside
  applications
