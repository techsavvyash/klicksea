#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an existing notarytool Keychain profile. See docs/SIGNING.md.}"
app="$PWD/dist/KlickSea.app"
codesign --verify --strict --verbose=2 "$app"
signature=$(codesign -dv "$app" 2>&1)
[[ "$signature" == *"Authority=Developer ID Application:"* ]] || {
    echo "Distribution requires a Developer ID Application certificate." >&2; exit 1;
}
ditto -c -k --keepParent "$app" "$PWD/dist/KlickSea-notarization.zip"
xcrun notarytool submit "$PWD/dist/KlickSea-notarization.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$PWD/dist/KlickSea.zip"
