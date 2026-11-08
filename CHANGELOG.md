# Changelog

## 0.2.3 - 2026-11-08
- Added: Use Default in Settings clears a custom snippets folder and returns to the default.
- Changed: Launch at Login is toggled only in the Settings window, not the menu-bar menu.
- Changed: Edit Config and Reveal moved into the Settings footer, dropping the full-width Config section.
- Changed: The Settings snippets hint is now a link to the snippet format docs on GitHub.

## 0.2.2 - 2026-11-06
- Fixed: Palette snippet search matches by keyword or name instead of only the exact keyword.

## 0.2.1 - 2026-11-06
- Changed: Local builds install as Heycast Dev, so they no longer reset the release Accessibility grant.

## 0.2.0 - 2026-11-06
- Added: Launch at Login through SMAppService, with a menu toggle, settings toggle and setup summary.
- Added: Settings window for shortcuts, snippets folder and Launch at Login; changes apply immediately.
- Added: Horizontal thirds and one-step Undo Window Move in the Window submenu.
- Added: Palette row actions: ⌘↩ reveal, ⌥⌘C copy path, ⌥⌘B copy bundle identifier.
- Added: Built-in palette commands: Sleep, Open Permissions and Open Config.
- Added: Text-snippet placeholders: {date}, {time}, {clipboard} and {uuid}, with escaped literal braces.
- Changed: Palette default is ⌥Space, snippets ⌥⇧Space; ⌘Space and ⌃Space stay with macOS.
- Changed: Accessibility is requested at first snippet or window use, not at launch.
- Changed: Releases use a stable signing identity and a fixed designated requirement, so updates keep Accessibility.
- Fixed: Snippet pastes restore the previous clipboard after the paste; a newer copy wins.

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
