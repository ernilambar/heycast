#!/usr/bin/env bash
# Regenerate Resources/AppIcon.icns from Resources/AppIcon.svg.
#
#   ./scripts/icon.sh
#
# The .icns is committed, so a normal build never needs this. Run it after
# editing the SVG. Only macOS tools are used: sips rasterizes the SVG at its
# intrinsic 1024x1024 and resamples it for the iconset, iconutil packs it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

svg="Resources/AppIcon.svg"
icns="Resources/AppIcon.icns"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

printf '==> rasterize %s\n' "$svg"
sips -s format png "$svg" --out "$work/icon_1024.png" >/dev/null

# iconutil only accepts the exact names and pixel sizes below.
iconset="$work/AppIcon.iconset"
mkdir -p "$iconset"
for spec in 16:16x16 32:16x16@2x 32:32x32 64:32x32@2x \
    128:128x128 256:128x128@2x 256:256x256 512:256x256@2x \
    512:512x512 1024:512x512@2x; do
    size="${spec%%:*}"
    name="${spec#*:}"
    sips -z "$size" "$size" "$work/icon_1024.png" \
        --out "$iconset/icon_$name.png" >/dev/null
done

printf '==> pack %s\n' "$icns"
iconutil -c icns "$iconset" -o "$icns"
printf 'wrote %s\n' "$icns"
