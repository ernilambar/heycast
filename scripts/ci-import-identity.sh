#!/usr/bin/env bash
# Import the "Heycast" release identity into a throwaway keychain.
#
# CI only. Reads the three secrets the release path needs:
#
#   HEYCAST_P12           base64 of the exported heycast.p12
#   HEYCAST_P12_PASSWORD  the .p12 password
#   KEYCHAIN_PASSWORD     password for the temporary keychain
#
# Creates the keychain under $RUNNER_TEMP, makes it the only searchable one and
# fails the job if any secret is empty or the identity does not import. Local
# machines should use scripts/release-cert.sh instead: this script throws the
# imported key away with the runner.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/lib.sh
. "$root/scripts/lib.sh"

require_secret() {
    if [ -z "${!1:-}" ]; then
        printf 'error: %s is empty; set it as a secret on the release environment\n' "$1" >&2
        exit 1
    fi
}

require_secret HEYCAST_P12
require_secret HEYCAST_P12_PASSWORD
require_secret KEYCHAIN_PASSWORD

keychain="${RUNNER_TEMP:-/tmp}/heycast.keychain-db"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$keychain"
# An unlocked keychain that locks itself after the build, not the runner's
# default session.
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$keychain"
security list-keychains -d user -s "$keychain"

# Keep the decoded key in RUNNER_TEMP so the runner's own cleanup removes it.
p12="${RUNNER_TEMP:-/tmp}/heycast.p12"
printf '%s' "$HEYCAST_P12" | base64 --decode >"$p12"
security import "$p12" -k "$keychain" \
    -P "$HEYCAST_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
rm -f "$p12"

# -T alone still lets codesign prompt; the partition list is what makes it
# non-interactive.
security set-key-partition-list -S apple-tool:,apple: -s \
    -k "$KEYCHAIN_PASSWORD" "$keychain" >/dev/null

if ! identity_present "$release_identity"; then
    printf 'error: identity "%s" did not import\n' "$release_identity" >&2
    security find-identity -p codesigning >&2 || true
    exit 1
fi

printf 'imported identity "%s"\n' "$release_identity"
