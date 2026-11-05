#!/usr/bin/env bash
# Shared helpers for dev.sh and bundle.sh. Sourced, never executed directly.
#
# Callers must set `root` to the repository root first.

# shellcheck disable=SC2154 # root is set by the caller before sourcing.
plist="$root/Resources/Info.plist"

# Bundle metadata lives in Resources/Info.plist alone; reading it here keeps a
# rename or version bump to one file.
plist_value() {
    plutil -extract "$1" raw -o - "$plist"
}

app_name="$(plist_value CFBundleName)"
executable="$(plist_value CFBundleExecutable)"
# shellcheck disable=SC2034 # read by dev.sh and bundle.sh after sourcing.
version="$(plist_value CFBundleShortVersionString)"
app="$root/dist/$app_name.app"

require_macos_arm64() {
    if [ "$(uname -s)" != "Darwin" ]; then
        printf 'error: this app targets macOS only (this host is %s)\n' "$(uname -s)" >&2
        exit 1
    fi
    # hw.optional.arm64 stays 1 on Apple silicon even under Rosetta, where
    # uname -m reports x86_64; checking the hardware keeps an Intel build from
    # passing as the supported target.
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" != "1" ]; then
        printf 'error: Apple silicon required; this is an Intel Mac\n' >&2
        exit 1
    fi
}

require_arm64_binary() {
    local arch
    arch="$(lipo -archs "$1")"
    if [ "$arch" != "arm64" ]; then
        printf 'error: expected an arm64 binary at %s, got: %s\n' "$1" "$arch" >&2
        exit 1
    fi
}

# assemble_bundle <config>: lay out dist/Heycast.app around the executable
# Swift already built for <config>, replacing any previous copy.
#
# Ad-hoc signing is enough: macOS refuses to launch an unsigned bundle on Apple
# silicon, and the app does not go through the notarized distribution path.
# It does cost the TCC grants, though: an ad-hoc signature's CDHash changes on
# every build, and macOS keys Privacy & Security entries to it, so every
# rebuild asks again. Export HEYCAST_SIGN_IDENTITY with a stable local identity
# (`security find-identity -p codesigning`) to keep grants across builds.
sign_identity="${HEYCAST_SIGN_IDENTITY:--}"

assemble_bundle() {
    local config="$1"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$root/.build/$config/$executable" "$app/Contents/MacOS/$executable"
    cp "$plist" "$app/Contents/Info.plist"
    codesign --force --sign "$sign_identity" "$app"
}
