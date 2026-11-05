#!/usr/bin/env bash
# Create a self-signed "Heycast Dev" codesigning identity in the login keychain.
#
#   ./scripts/dev-cert.sh
#
# A stable identity keeps TCC grants across rebuilds; see assemble_bundle in
# scripts/lib.sh, which picks this identity up automatically. Safe to rerun:
# an existing identity is left alone.
set -euo pipefail

name="Heycast Dev"
keychain="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning "$keychain" | grep -q "\"$name\""; then
    printf 'identity "%s" already exists\n' "$name"
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# /usr/bin/openssl is LibreSSL, whose PKCS#12 defaults `security import`
# accepts; Homebrew's OpenSSL 3 writes algorithms it rejects.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -subj "/CN=$name" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null

# security import fails on an empty PKCS#12 password, so use a throwaway one.
/usr/bin/openssl pkcs12 -export -passout pass:heycast \
    -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/id.p12"

# -T lets codesign use the key without a keychain prompt on every build.
security import "$tmp/id.p12" -k "$keychain" -P heycast -T /usr/bin/codesign

printf 'created identity "%s"\n' "$name"
