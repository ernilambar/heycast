# Positioning

## The sentence

> Heycast is a menu-bar launcher for everyday Mac work: one shortcut opens apps,
> pastes snippets, and snaps windows; nothing leaves your Mac and there is no
> account.

Say it exactly this way everywhere a one-liner is needed: the README, the About
window, the Homebrew cask `desc`, the GitHub repository description and the
first line of a release announcement. A shorter form is allowed only when space
forces it, and then it is the first clause:

> A menu-bar launcher for everyday Mac work: apps, snippets, and windows from
> one shortcut.

## Who it is for

Someone who uses a Mac for work but is not a developer: writers, designers,
people in sales, support and operations. They want the apps they already own to
open faster, the text they retype all day to paste itself, and the window in
front to fill half the screen — with one hand on the keyboard.

It is not for people who want to script their desktop, build a plugin, or keep a
configuration repository. Those users have other tools, and chasing them would
add an extension surface the product deliberately does not have.

## What the sentence promises

- **Menu bar, not a window.** No Dock icon, no main window, nothing to launch
  from Launchpad. It is already running.
- **One shortcut.** The palette is the front door. A second shortcut, snippets,
  and a small set of window shortcuts are the whole surface.
- **Everyday work, not developer work.** Apps, snippets and window layouts
  only. No file search, calculator, web search or workflow runtime.
- **Your Mac.** Local-first: plain files in Application Support, no account, no
  sync, no server.

## What it never says

- No "Spotlight replacement", "supercharged", "AI-powered", "productivity
  system" or "workflow automation".
- No competitor comparison table. The README describes Heycast only.
- No telemetry or privacy claim beyond what is true and verifiable: no
  analytics, no install ID, no crash SDK, no network traffic. State "no
  telemetry" plainly; do not quantify it as a promise about future releases.
- No mention of notarization, signing or Homebrew internals in the sentence.
  Those belong in install instructions.

## Why this framing

App launchers sell on speed, snippet tools on retyping, window managers on
layout. Heycast's only defensible claim is that all three sit behind one
keyboard shortcut in a small native app that never phones home. Keeping the
sentence to one line is what keeps the scope to Phase 2–4: anything the sentence
does not promise is out of scope by default.
