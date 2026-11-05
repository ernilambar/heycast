#!/usr/bin/env bash
# Run the quality gate and build the publishable macOS bundle.
#
#   ./scripts/bundle.sh
#
# Produces the artifacts a release publishes: the .app bundle, its
# -macos-arm64.zip archive and SHA256SUMS, all under dist/. Only darwin/arm64
# is supported: no Intel build, no universal binary.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# shellcheck source=scripts/lib.sh
. "$root/scripts/lib.sh"

require_macos_arm64

printf '==> plutil\n'
plutil -lint "$plist"

printf '==> swift build (release)\n'
swift build -c release

require_arm64_binary "$root/.build/release/$executable"

printf '==> bundle\n'
rm -rf "$root/dist"
mkdir -p "$root/dist"
assemble_bundle release

require_arm64_binary "$app/Contents/MacOS/$executable"
codesign --verify --deep --strict "$app"

printf '==> package\n'
zip="dist/$app_name-macos-arm64.zip"
# --norsrc --noextattr keeps AppleDouble ._* entries out of the archive; the
# signature lives in the Mach-O and CodeResources, not in an xattr.
ditto -c -k --norsrc --noextattr --keepParent "$app" "$zip"
(cd dist && shasum -a 256 "$app_name-macos-arm64.zip" >SHA256SUMS)

printf '\nbundle:  %s\narchive: %s\ndigest:  %s\n' \
    "$app" "$zip" "$(cat dist/SHA256SUMS)"
