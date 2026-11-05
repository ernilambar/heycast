# heycast

A macOS palette app: SwiftUI content hosted in a borderless, floating
`NSPanel`. This first cut is a hello world — a status-bar app that opens a
launcher-style palette, focuses a text field, and reports back what you type.

## Requirements

- macOS 14+
- Swift 6 toolchain (Command Line Tools are enough; Xcode is not required)

## Build & run

```sh
make run     # build, bundle into .build/Heycast.app, launch
make stop    # quit an already running instance
make clean
```

The app is an accessory (`LSUIElement`) app: no Dock icon, one status-bar
item. Click it to open the palette.

- left-click the status-bar item to toggle it
- right-click it for "Open Palette" / "Quit Heycast"
- `esc` or focusing another app closes the palette

## Layout

```
Sources/Heycast/
  HeycastApp.swift       @main entry, accessory activation policy
  AppDelegate.swift      status-bar item + panel lifecycle
  PaletteController.swift NSPanel configuration, placement, esc/click-away
  PaletteView.swift      SwiftUI palette content + model
Resources/Info.plist     LSUIElement, bundle metadata
Makefile                 swift build + .app bundle assembly
```

The panel is transparent and borderless, sized 620×132, centered on the
screen under the pointer and offset 20% from the top. It is
`nonactivatingPanel` + `canBecomeKey`, so it can take keyboard focus from the
launcher.

## Next

- Global hotkey (no accessibility permission needed via Carbon `RegisterEventHotKey`)
- Real command execution and results list
