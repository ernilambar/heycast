#!/usr/bin/env bash
# Create and export the "Heycast" release signing identity.
#
#   ./scripts/release-cert.sh            # create the identity and export the .p12
#   ./scripts/release-cert.sh --record   # rewrite Resources/release-identity.txt
#   ./scripts/release-cert.sh --print    # print the exported .p12 as base64
#
# One identity signs every published build. It is deliberately separate from the
# local "Heycast Dev" identity (scripts/dev-cert.sh): the release key is the TCC
# key for every installed copy, so rotating or losing it resets Accessibility
# for all users at the next `brew upgrade`.
#
# The certificate and private key are exported to $HEYCAST_RELEASE_DIR (default
# ~/.heycast/release), never into the repository. Back that folder up somewhere
# that outlives this Mac, then store the .p12 and its password as GitHub Actions
# secrets so CI can sign without the key ever living in the repo.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# shellcheck source=scripts/lib.sh
. "$root/scripts/lib.sh"

release_dir="${HEYCAST_RELEASE_DIR:-$HOME/.heycast/release}"
p12="$release_dir/heycast.p12"
password_file="$release_dir/password.txt"
keychain="${HEYCAST_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

# Set by create_identity and cleaned up by its trap; not local for that reason.
work=""

mode="create"
case "${1:-}" in
--record) mode="record" ;;
--print) mode="print" ;;
"") ;;
*)
    printf 'usage: %s [--record|--print]\n' "$0" >&2
    exit 2
    ;;
esac

# Everything written from here on is secret: the .p12 holds the private key.
umask 077

random_secret() {
    # openssl writes its whole output before exiting, so the pipe never carries
    # a SIGPIPE-canceled status under `set -o pipefail`.
    /usr/bin/openssl rand -base64 48 | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-"${1:-32}"
}

read_password() {
    if [ ! -f "$password_file" ]; then
        printf 'error: %s is missing; the exported key has no password\n' "$password_file" >&2
        exit 1
    fi
    tr -d '\n' <"$password_file"
}

record_requirement() {
    local requirement
    if ! identity_present "$release_identity"; then
        printf 'error: identity "%s" is not in the keychain\n' "$release_identity" >&2
        printf '  import it first:\n' >&2
        printf '  security import %s -k %s -P "$(cat %s)" -T /usr/bin/codesign\n' \
            "$p12" "$keychain" "$password_file" >&2
        exit 1
    fi
    requirement="$(designated_requirement_for_identity "$release_identity")"
    if [ -z "$requirement" ]; then
        printf 'error: could not derive a designated requirement for "%s"\n' "$release_identity" >&2
        exit 1
    fi
    printf '%s\n' "$requirement" >"$designated_requirement_file"
    printf 'recorded %s\n  %s\n' "$designated_requirement_file" "$requirement"
}

export_existing_identity() {
    # The keychain already has the identity but the backup is gone. Export it
    # rather than minting a second certificate: a new certificate changes the
    # designated requirement and revokes every Accessibility grant.
    local password
    password="$(random_secret 32)"
    printf 'exporting "%s" from %s (macOS may ask for the keychain password)\n' \
        "$release_identity" "$keychain" >&2
    mkdir -p "$release_dir"
    if ! security export -k "$keychain" -t identities -f pkcs12 \
        -P "$password" -o "$p12" >/dev/null 2>&1; then
        printf 'error: could not export the identity\n' >&2
        printf '  run it by hand and allow the export:\n' >&2
        printf '  security export -k %s -t identities -f pkcs12 -o %s\n' \
            "$keychain" "$p12" >&2
        exit 1
    fi
    printf '%s\n' "$password" >"$password_file"
    printf 'exported %s\n' "$p12"
}

create_identity() {
    if identity_present "$release_identity"; then
        printf 'identity "%s" already exists in %s\n' "$release_identity" "$keychain"
        if [ ! -e "$p12" ]; then
            export_existing_identity
        fi
        return
    fi

    if [ -e "$p12" ]; then
        # Keychain reset but the backup survived: restore it instead of minting
        # a second certificate, which would change the designated requirement.
        printf 'importing the existing identity from %s\n' "$p12"
        security import "$p12" -k "$keychain" -P "$(read_password)" \
            -T /usr/bin/codesign -T /usr/bin/security
        return
    fi

    local password
    # Traps run after the function returns, so the path cannot be local.
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    password="$(random_secret 32)"

    # /usr/bin/openssl is LibreSSL, whose PKCS#12 defaults `security import`
    # accepts; Homebrew's OpenSSL 3 writes algorithms it rejects. Ten years,
    # codeSigning EKU, and no CA:true, so the leaf is the whole identity.
    /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -subj "/CN=$release_identity" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" \
        -addext "basicConstraints=critical,CA:false" \
        -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null

    mkdir -p "$release_dir"
    /usr/bin/openssl pkcs12 -export -passout pass:"$password" \
        -inkey "$work/key.pem" -in "$work/cert.pem" -out "$p12"
    printf '%s\n' "$password" >"$password_file"

    security import "$p12" -k "$keychain" -P "$password" \
        -T /usr/bin/codesign -T /usr/bin/security

    # CI imports into a throwaway keychain it owns the password for; the login
    # keychain has no such password to hand over here.
    if [ -n "${HEYCAST_KEYCHAIN_PASSWORD:-}" ]; then
        security set-key-partition-list -S apple-tool:,apple: -s \
            -k "$HEYCAST_KEYCHAIN_PASSWORD" "$keychain" >/dev/null 2>&1 ||
            printf 'note: could not set the key partition list; codesign may prompt\n' >&2
    fi

    printf 'created identity "%s"\n' "$release_identity"
}

print_next_steps() {
    local repo="${HEYCAST_GITHUB_REPO:-ernilambar/heycast}"
    printf '\nidentity:  %s\nbackup:    %s\npassword:  %s\n\n' \
        "$release_identity" "$p12" "$password_file"
    printf 'The .p12 and its password are the release key. Copy both somewhere\n'
    printf 'that outlives this Mac before doing anything else.\n\n'
    printf 'Store them as GitHub Actions secrets:\n\n'
    printf '  base64 -i %s | gh secret set HEYCAST_P12 --repo %s\n' "$p12" "$repo"
    printf '  gh secret set HEYCAST_P12_PASSWORD --repo %s < %s\n' "$repo" "$password_file"
    printf '  %s | gh secret set KEYCHAIN_PASSWORD --repo %s\n' \
        "$(random_secret 32)" "$repo"
    printf '\nImport the identity on any other machine that signs a release:\n\n'
    printf '  security import %s -k login.keychain-db -P "$(cat %s)" -T /usr/bin/codesign\n' \
        "$p12" "$password_file"
    printf '\nCheck a release build against the recorded requirement:\n\n'
    printf '  ./scripts/bundle.sh --release\n'
}

case "$mode" in
create)
    create_identity
    record_requirement
    print_next_steps
    ;;
record)
    record_requirement
    ;;
print)
    printf 'backup: %s\npassword: %s\n\n' "$p12" "$password_file"
    base64 -i "$p12"
    printf '\n'
    ;;
esac
