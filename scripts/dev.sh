#!/usr/bin/env bash
# Build the app bundle, install it to /Applications and relaunch it.
#
#   ./scripts/dev.sh             debug build
#   ./scripts/dev.sh --release   release build, with an arm64 arch check
#
# Installing the bundle is what makes bundle-only behaviour testable: the
# LaunchServices registration, the accessory activation policy and the
# status-bar item come from the bundle, not from a bare binary. The copy
# already in /Applications is killed first, so its open palette is lost.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# shellcheck source=scripts/lib.sh
. "$root/scripts/lib.sh"

dest="/Applications/$app_name.app"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

usage() {
    cat <<'EOF'
usage: scripts/dev.sh [--release]

  --release  build with release flags and verify the arm64 arch

Builds dist/Heycast.app, installs it to /Applications, registers it with
LaunchServices and launches it.
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
mkdir -p "$root/dist"
assemble_bundle "$config"

if pkill -f "$dest/Contents/MacOS/"; then
    while pgrep -f "$dest/Contents/MacOS/" >/dev/null; do
        sleep 0.1
    done
fi

rm -rf "$dest"
ditto "$app" "$dest"
# Finder only notices a replaced bundle once LaunchServices forgets the old one.
"$lsregister" -f "$dest"

printf 'Installed %s (%s) to %s\n' "$app" "$version" "$dest"

open "$dest"
