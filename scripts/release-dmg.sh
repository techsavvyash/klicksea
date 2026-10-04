#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPER_ID_APPLICATION_SHA1:?Set the SHA-1 of your Developer ID Application identity.}"
: "${NOTARY_PROFILE:?Set a stored notarytool Keychain profile.}"
[[ "$DEVELOPER_ID_APPLICATION_SHA1" =~ ^[[:xdigit:]]{40}$ ]] || { echo 'Expected a certificate SHA-1 fingerprint.' >&2; exit 1; }
security find-identity -v -p codesigning | /usr/bin/grep -F "$DEVELOPER_ID_APPLICATION_SHA1" >/dev/null || { echo 'Developer ID private key is unavailable in Keychain.' >&2; exit 1; }
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
mkdir -p dist/release
stage=$(mktemp -d "$PWD/dist/.release.XXXXXX")
trap 'rm -rf "$stage"' EXIT
app="$stage/KlickSea.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
for arch in arm64 x86_64; do
    swift build -c release --arch "$arch" --scratch-path ".build-release/$arch"
    directory=$(swift build -c release --arch "$arch" --scratch-path ".build-release/$arch" --show-bin-path)
    cp "$directory/KlickSea" "$stage/KlickSea-$arch"
done
lipo -create "$stage/KlickSea-arm64" "$stage/KlickSea-x86_64" -output "$app/Contents/MacOS/KlickSea"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign "$DEVELOPER_ID_APPLICATION_SHA1" --options runtime --timestamp --entitlements Resources/KlickSea.entitlements "$app"
signature=$(codesign -dv "$app" 2>&1)
[[ "$signature" == *'Authority=Developer ID Application:'* ]] || { echo 'Refusing to release a local/self-signed app.' >&2; exit 1; }
codesign --verify --strict --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$stage/app-notarization.zip"
xcrun notarytool submit "$stage/app-notarization.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
mkdir "$stage/image"
ditto "$app" "$stage/image/KlickSea.app"
ln -s /Applications "$stage/image/Applications"
dmg="$PWD/dist/release/KlickSea-$version-universal.dmg"
[[ ! -e "$dmg" ]] || { echo "Release artifact already exists: $dmg. Bump the version or move it aside." >&2; exit 1; }
hdiutil create -volname KlickSea -srcfolder "$stage/image" -format UDZO -ov "$dmg"
codesign --sign "$DEVELOPER_ID_APPLICATION_SHA1" --timestamp "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
codesign --verify --verbose=2 "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
shasum -a 256 "$dmg" > "$dmg.sha256"
echo "Verified release: $dmg"
