#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

name="KlickSea Local Development"
keychain=$(security default-keychain -d user | tr -d '"' | sed 's/^[[:space:]]*//')
openssl_bin="/opt/homebrew/opt/openssl@3/bin/openssl"
[[ -x "$openssl_bin" ]] || { echo "OpenSSL 3 is required to generate the local certificate." >&2; exit 1; }

# Reuse a valid existing identity. Never rotate a key as part of a rebuild.
fingerprint=$(security find-identity -v -p codesigning "$keychain" | \
    awk -v name="\"$name\"" 'index($0, name) { print $2; exit }')
if [[ -z "$fingerprint" ]]; then
    if security find-certificate -c "$name" "$keychain" >/dev/null 2>&1; then
        echo "A certificate with this name exists but is not a valid identity. Repair it in Keychain Access instead of replacing its key." >&2
        exit 1
    fi
    [[ ! -f .signing.env && ! -f .signing-identity ]] || {
        echo "This project already pins an identity. Restore that certificate instead of generating another." >&2; exit 1;
    }
    umask 077
    temporary=$(mktemp -d /private/tmp/klicksea-signing.XXXXXX)
    trap 'rm -rf "$temporary"' EXIT
    "$openssl_bin" rand -hex 32 > "$temporary/password"
    "$openssl_bin" req -x509 -newkey rsa:3072 -sha256 -nodes -days 3650 \
        -subj "/CN=$name/" \
        -addext 'basicConstraints=critical,CA:FALSE' \
        -addext 'keyUsage=critical,digitalSignature' \
        -addext 'extendedKeyUsage=critical,codeSigning' \
        -keyout "$temporary/key.pem" -out "$temporary/certificate.pem" 2>"$temporary/generation.log"
    "$openssl_bin" pkcs12 -export -legacy -name "$name" \
        -inkey "$temporary/key.pem" -in "$temporary/certificate.pem" \
        -passout "file:$temporary/password" -out "$temporary/identity.p12"
    password=$(cat "$temporary/password")
    security import "$temporary/identity.p12" -k "$keychain" -P "$password" -T /usr/bin/codesign
    unset password
    # User-level trust is restricted to code signing, not TLS or other policies.
    security add-trusted-cert -r trustRoot -p codeSign -k "$keychain" "$temporary/certificate.pem"
    fingerprint=$(security find-identity -v -p codesigning "$keychain" | \
        awk -v name="\"$name\"" 'index($0, name) { print $2; exit }')
fi
[[ "$fingerprint" =~ ^[[:xdigit:]]{40}$ ]] || {
    echo "The certificate was imported but is not yet a valid identity. Check Code Signing trust in Keychain Access." >&2; exit 1;
}
if [[ -f .signing.env ]]; then
    source .signing.env
    [[ "${SIGNING_IDENTITY:-}" == "$fingerprint" ]] || {
        echo "Existing signing configuration uses another identity; it has been preserved." >&2; exit 1;
    }
else
    printf 'SIGNING_IDENTITY="%s"\nSIGNING_TIMESTAMP=none\n' "$fingerprint" > .signing.env
fi
echo "Persistent local identity ready: $name ($fingerprint)"
echo "The private key is in your login Keychain. Export an encrypted .p12 backup using Keychain Access."
