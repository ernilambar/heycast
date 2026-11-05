# Changelog

All notable changes to Heycast. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Heycast follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html): `0.x` until the
planned phases ship, `1.0.0` only after the release is validated with real
users.

The release workflow refuses a tag without a matching `## [version]` section
here, and the GitHub release body links to this file. This is the only
release-notes source.

## [Unreleased]

### Added

- Release signing with the stable `Heycast` identity: the release workflow now
  fails instead of shipping an ad-hoc build, and every build is checked against
  the committed designated requirement so an update cannot silently reset
  Accessibility.
- This changelog, the release cadence it enforces, and the signed release gate.

### Changed

- The About panel and README lead with the product's one-sentence positioning.

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
