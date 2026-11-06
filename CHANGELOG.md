# Changelog

## X.X.X - YYYY-MM-DD
- Added: Horizontal thirds in the Window submenu: left third, left two thirds, right third and right two thirds.
- Added: One-step Undo Window Move in the Window submenu, one frame per window, in memory only.
- Added: Full-screen windows are skipped and logged, so a window command never forces a Space transition.
- Added: Palette row actions: ⌘↩ reveal, ⌥⌘C copy path, ⌥⌘B copy bundle identifier, with footer hints.
- Added: Built-in palette commands matched by name: Sleep, Open Permissions and Open Config.
- Added: Text-snippet placeholders expanded at paste time: {date}, {time}, {clipboard} and {uuid}.
- Added: {{ and }} escape literal braces; an unknown {name} stays literal and logs once per run.
- Added: Invalid snippet files appear in the snippets scope with the validation reason.
- Added: ⌘↩ reveals a snippet, or an invalid snippet, in Finder.
- Added: The About panel states that Heycast collects no telemetry.
- Changed: Palette snippets match only the exact, case-sensitive keyword; titles are display-only.
- Changed: Lock Screen is not offered; macOS 26 removed CGSession and the remaining paths need private APIs.
- Changed: README has a Privacy section: no telemetry, no analytics, no network calls, local files only.
- Changed: docs/snippets.md and docs/search.md cover placeholders, validation, commands and row actions.
- Changed: CHANGELOG.md now uses flatlog; CI and the release workflow validate its structure.

## 0.2.0 - 2026-11-05
- Added: Launch at Login through SMAppService, with a menu toggle, settings toggle and setup summary.
- Added: Settings window for shortcuts, snippets folder and Launch at Login; writes config.json atomically.
- Added: Live reload: a new shortcut or snippets folder applies immediately; hand edits are picked up too.
- Added: Shortcut conflict warnings for macOS-owned bindings and RegisterEventHotKey failures.
- Added: Move to /Applications step in setup when the app runs from elsewhere.
- Added: Release signing with the stable Heycast identity; a missing certificate fails the build.
- Added: Designated-requirement check so updates cannot silently reset Accessibility.
- Changed: Palette default is ⌥Space, snippets ⌥⇧Space; ⌘Space and ⌃Space stay with macOS.
- Changed: Accessibility is requested at first snippet or window use, not at launch.
- Changed: App catalog rescans on every palette open in the background.
- Changed: README leads with the demo, two-command brew install and update command; the zip path is gone.
- Changed: Homebrew 7 tap trust is documented as required.
- Changed: About panel and README lead with the product positioning.
- Fixed: Snippet pastes restore the previous clipboard after the paste; a newer copy wins.
- Fixed: A missing hotkey registration is no longer log-only.

## 0.1.0 - 2026-11-05
- Added: Menu-bar palette for apps in /Applications, /System/Applications and ~/Applications, ranked by usage.
- Added: Snippet expansion and pasting from Markdown front matter, including script snippets.
- Added: Window management for halves, maximize and center.
- Added: Configurable global shortcuts in config.json, with an Edit Config menu item.
- Added: Accessibility setup wizard, reopenable from the menu.
- Added: About panel with the app version and project links.
- Added: Unit tests for the pure logic and CI on macos-15.
- Changed: Apple silicon only, macOS 14 or later; no Intel build.
- Changed: Not notarized; the Homebrew cask clears quarantine and a manual unzip is blocked.
- Changed: No login item or in-app updater; update with brew upgrade --cask heycast.
- Changed: Configuration changes apply on the next launch.
- Changed: No telemetry of any kind and no crash reporting.
