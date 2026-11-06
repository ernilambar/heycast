#!/usr/bin/env bash
# Build the app bundle, install it to /Applications and relaunch it.
#
#   ./scripts/dev.sh             debug build
#   ./scripts/dev.sh --release   release build, with an arm64 arch check
#
# Installing the bundle is what makes bundle-only behaviour testable: the
# LaunchServices registration, the accessory activation policy and the
# status-bar item come from the bundle, not from a bare binary. Every running
# copy is quit first, release included: both register the same global
# shortcuts, and only one process can hold them.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# shellcheck source=scripts/lib.sh
. "$root/scripts/lib.sh"

lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

usage() {
    cat <<'EOF'
usage: scripts/dev.sh [--release]

  --release  build with release flags and verify the arm64 arch

Builds dist/Heycast.app, installs it to /Applications (as "Heycast Dev.app"
unless signed with the release identity), registers it with LaunchServices
and launches it.
EOF
}

release=false
for arg in "$@"; do
    case "$arg" in
        --release) release=true ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'unknown argument: %s\n\n' "$arg" >&2
            usage >&2
            exit 2
            ;;
    esac
done

require_macos_arm64
resolve_sign_identity
dest="/Applications/$bundle_name.app"

config="debug"
if $release; then
    config="release"
fi

printf '==> swift build (%s)\n' "$config"
swift build -c "$config"

if $release; then
    require_arm64_binary "$root/.build/$config/$executable"
fi

printf '==> bundle\n'
printf 'signing identity: %s\n' "$sign_identity"
printf 'bundle identifier: %s\n' "$bundle_id"
mkdir -p "$root/dist"
assemble_bundle "$config"

if pkill -x "$executable"; then
    while pgrep -x "$executable" >/dev/null; do
        sleep 0.1
    done
fi

rm -rf "$dest"
ditto "$app" "$dest"
# Finder only notices a replaced bundle once LaunchServices forgets the old one.
"$lsregister" -f "$dest"

printf 'Installed %s (%s) to %s\n' "$app" "$version" "$dest"

open "$dest"
