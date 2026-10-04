#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# This optional, ignored file pins a certificate fingerprint across rebuilds.
if [[ -f .signing.env ]]; then source .signing.env; fi
mode="${1:-signed}"
case "$mode" in signed|--unsigned) ;; *) echo "Usage: $0 [--unsigned]" >&2; exit 2;; esac
if [[ "$mode" == signed ]]; then
    : "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a persistent certificate SHA-1 fingerprint. See docs/SIGNING.md.}"
    if [[ ! "$SIGNING_IDENTITY" =~ ^[[:xdigit:]]{40}$ ]]; then
        echo "Use the exact SHA-1 fingerprint from security find-identity, not ad-hoc signing or a certificate name." >&2
        exit 1
    fi
    identities=$(security find-identity -v -p codesigning)
    if ! [[ "$identities" == *"$SIGNING_IDENTITY"* ]]; then
        echo "The pinned signing identity is unavailable. Restore it instead of creating a new key." >&2
        exit 1
    fi
    if [[ -f .signing-identity && "$(cat .signing-identity)" != "$SIGNING_IDENTITY" ]]; then
        echo "Signing identity changed. Review docs/SIGNING.md before intentionally updating .signing-identity." >&2
        exit 1
    fi
fi

swift build -c release
binary_dir=$(swift build -c release --show-bin-path)
mkdir -p dist
stage=$(mktemp -d "$PWD/dist/.stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
app="$stage/KlickSea.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/KlickSea" "$app/Contents/MacOS/KlickSea"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
plutil -lint "$app/Contents/Info.plist"

if [[ "$mode" == signed ]]; then
    timestamp=(--timestamp)
    if [[ "${SIGNING_TIMESTAMP:-}" == none ]]; then timestamp=(--timestamp=none); fi
    codesign --force --sign "$SIGNING_IDENTITY" --options runtime "${timestamp[@]}" \
        --entitlements Resources/KlickSea.entitlements "$app"
    codesign --verify --strict --verbose=2 "$app"
    # The previous requirement must accept this build before it replaces the app.
    if [[ -f .signing-requirement ]]; then
        codesign --verify --strict -R="$(cat .signing-requirement)" "$app"
    fi
    requirement=$(codesign -d -r- "$app" 2>&1 | sed -n 's/^designated => //p')
    [[ -n "$requirement" ]] || { echo "Missing designated requirement" >&2; exit 1; }
    printf '%s\n' "$SIGNING_IDENTITY" > .signing-identity
    printf '%s\n' "$requirement" > .signing-requirement
    destination="$PWD/dist/KlickSea.app"
else
    # Separate identity and filename: this artifact is for inspection, not TCC testing.
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.techsavvyash.klicksea.unsigned' "$app/Contents/Info.plist"
    destination="$PWD/dist/KlickSea-Unsigned.app"
fi
if [[ -e "$destination" ]]; then
    # Preserve the previous complete bundle while replacing it with the staged build.
    backup="$stage/previous.app"
    mv "$destination" "$backup"
fi
mv "$app" "$destination"
echo "Built $destination"
