# Changelog

All notable changes to Heycast. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Heycast follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html): `0.x` until the
planned phases ship, `1.0.0` only after the release is validated with real
users.

The release workflow refuses a tag without a matching `## [version]` section
here, and the GitHub release body links to this file. This is the only
release-notes source.

## [0.2.0] - 2026-11-05

Phase 1: install and survive. One brew-only install path, a signed release, a
login item, live settings, and a snippet paste that gives the clipboard back.

### Added

- Launch at Login through `SMAppService`, with a toggle in the menu-bar item,
  the settings window and the setup summary. The approval state in System
  Settings is shown instead of being treated as an error.
- Settings window: record or remove any global shortcut, choose the snippets
  folder, and toggle Launch at Login. It writes `config.json` atomically and
  leaves unknown keys untouched.
- Live reload: a new shortcut or snippets folder takes effect immediately, and
  a hand edit to `config.json` is picked up without a relaunch.
- Shortcut conflict warnings: the settings window compares every binding with
  the shortcuts macOS owns (Spotlight, input sources, Mission Control,
  screenshots, …) and shows `RegisterEventHotKey` failures, each with a Change
  shortcut action.
- A "Move to /Applications" setup step when the app runs from anywhere else,
  because macOS records Accessibility against the bundle path.
- Release signing with the stable `Heycast` identity: the release workflow now
  fails instead of shipping an ad-hoc build, and every build is checked against
  the committed designated requirement so an update cannot silently reset
  Accessibility.
- This changelog, the release cadence it enforces, and the signed release gate.

### Changed

- The palette default is `⌥Space` and the snippets default is `⌥⇧Space`.
  `⌘Space` stays with Spotlight and `⌃Space` with input sources.
- Accessibility is requested at first snippet or window use, not at launch.
  Launching apps needs no grant. The setup-complete flag is written only when
  the wizard is finished, and "Permissions…" reopens it.
- The application catalog is rescanned on every palette open, in the
  background, so an app installed while Heycast runs appears on the next open.
- The README leads with a 10-second palette demo, what Heycast does, the
  two-command brew install, and the update command; the zip download path is
  gone. Homebrew 7's tap trust is documented as required.
- The About panel and README lead with the product's one-sentence positioning.

### Fixed

- Snippet pastes restore the previous clipboard after the paste instead of
  leaving the snippet text on it. A newer copy in the meantime wins.
- A missing hotkey registration is no longer log-only.

## [0.1.0] - 2026-11-05

First public build: an arm64, menu-bar-only palette.

### Added

- Menu-bar launcher palette for applications in `/Applications`,
  `/System/Applications` and `~/Applications`, ranked by launch count and
  recency.
- Snippet expansion and snippet pasting from Markdown files with `keyword`
  front matter, including script snippets whose output is pasted.
- Window management: left, right, top and bottom halves, maximize and center.
- Configurable global shortcuts declared in `config.json`, with an "Edit
  Config…" menu item that seeds a template.
- First-run permission wizard for Accessibility, reopenable from the menu.
- About panel with the app version and project links.
- Unit tests for the pure logic (search ranking, snippet parsing, keymap
  resolution, usage scoring) and CI on `macos-15`.

### Known limitations

- Apple silicon only, macOS 14 or later. No Intel build.
- Not notarized. The Homebrew cask clears the download quarantine; a manual
  unzip does not, and Gatekeeper blocks it.
- No login item, no in-app updater. Update with `brew upgrade --cask heycast`.
- Configuration changes take effect on the next launch.
- No telemetry of any kind, and no crash reporting.
