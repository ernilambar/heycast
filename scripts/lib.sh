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

# Two signing identities, never mixed:
#
#   "Heycast Dev"  local builds, created by scripts/dev-cert.sh
#   "Heycast"      published builds, created by scripts/release-cert.sh and
#                  imported from Actions secrets in CI
#
# macOS keys Privacy & Security grants to the signature, so an ad-hoc build
# (`-`) loses Accessibility on every rebuild and every update. A release signed
# ad-hoc therefore looks like a permissions bug to the user; HEYCAST_RELEASE=1
# turns that fallback into a hard failure instead.
#
# Rotating "Heycast" changes the designated requirement and resets Accessibility
# for everyone, so the expected requirement is committed in
# Resources/release-identity.txt and checked on every release build.
release_identity="Heycast"
development_identity="Heycast Dev"
designated_requirement_file="$root/Resources/release-identity.txt"

identity_present() {
    security find-identity -p codesigning 2>/dev/null | grep -q "\"$1\""
}

# resolve_sign_identity: set `sign_identity` for the bundle about to be built.
# Honours HEYCAST_SIGN_IDENTITY first, then the identity for the build mode.
resolve_sign_identity() {
    if [ -n "${HEYCAST_SIGN_IDENTITY:-}" ]; then
        sign_identity="$HEYCAST_SIGN_IDENTITY"
        return
    fi
    if [ "${HEYCAST_RELEASE:-0}" = "1" ]; then
        if ! identity_present "$release_identity"; then
            printf 'error: release builds must sign with "%s", not ad-hoc\n' "$release_identity" >&2
            printf '  create it with scripts/release-cert.sh, then import heycast.p12\n' >&2
            exit 1
        fi
        sign_identity="$release_identity"
        return
    fi
    # Local builds prefer the dev identity so the release key is only used by
    # the release path; ad-hoc is the last resort and gets a warning.
    if identity_present "$development_identity"; then
        sign_identity="$development_identity"
    else
        sign_identity="-"
        printf 'warning: no signing identity found; signing ad-hoc\n' >&2
        printf '  run make dev-cert to keep TCC grants across rebuilds\n' >&2
    fi
}

# designated_requirement <bundle>: the requirement codesign wrote, e.g.
# identifier "net.nilambar.heycast" and certificate leaf = H"..."
designated_requirement() {
    codesign -d -r- "$1" 2>&1 | sed -n 's/^designated => //p'
}

# designated_requirement_for_identity <identity>: signs a stub bundle carrying
# the real Info.plist, which yields the same requirement as the app without a
# full build. Used to record the requirement and to compare identities.
designated_requirement_for_identity() {
    local dir stub requirement
    dir="$(mktemp -d)"
    stub="$dir/$app_name.app"
    mkdir -p "$stub/Contents/MacOS"
    cp "$plist" "$stub/Contents/Info.plist"
    cp /usr/bin/true "$stub/Contents/MacOS/$executable"
    codesign --force --sign "$1" "$stub" >/dev/null 2>&1
    requirement="$(designated_requirement "$stub")"
    rm -rf "$dir"
    printf '%s\n' "$requirement"
}

# check_designated_requirement <bundle>: compare the built bundle against the
# committed requirement. A mismatch means the signing identity changed, which
# silently revokes Accessibility for every existing install on update.
check_designated_requirement() {
    local actual expected
    actual="$(designated_requirement "$1")"
    if [ -z "$actual" ]; then
        printf 'error: %s carries no designated requirement\n' "$1" >&2
        exit 1
    fi
    # Local builds sign with "Heycast Dev", so their requirement is expected to
    # differ; only a build signed with the release identity has to match.
    if [ "$sign_identity" != "$release_identity" ]; then
        printf 'designated requirement: %s (development build)\n' "$actual"
        return
    fi
    if [ ! -f "$designated_requirement_file" ]; then
        if [ "${HEYCAST_RELEASE:-0}" = "1" ]; then
            printf 'error: %s is missing; record it with\n' "$designated_requirement_file" >&2
            printf '  ./scripts/release-cert.sh --record\n' >&2
            exit 1
        fi
        printf 'designated requirement: %s (unrecorded)\n' "$actual" >&2
        return
    fi
    expected="$(tr -d '\n' <"$designated_requirement_file")"
    if [ "$actual" != "$expected" ]; then
        printf 'error: designated requirement changed\n' >&2
        printf '  expected: %s\n' "$expected" >&2
        printf '  actual:   %s\n' "$actual" >&2
        printf '  the signing identity was rotated; every existing Accessibility\n' >&2
        printf '  grant is now stale. Restore the original identity, or record the\n' >&2
        printf '  change with scripts/release-cert.sh --record and tell users to\n' >&2
        printf '  grant Accessibility again.\n' >&2
        exit 1
    fi
    printf 'designated requirement: %s\n' "$actual"
}

# assemble_bundle <config>: lay out dist/Heycast.app around the executable
# Swift already built for <config>, replacing any previous copy.
assemble_bundle() {
    local config="$1"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$root/.build/$config/$executable" "$app/Contents/MacOS/$executable"
    cp "$plist" "$app/Contents/Info.plist"
    cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
    codesign --force --sign "$sign_identity" "$app"
}
