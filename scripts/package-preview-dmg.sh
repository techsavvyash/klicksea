#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source .signing.env
: "${SIGNING_IDENTITY:?Run scripts/setup-local-signing.sh first.}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
mkdir -p dist/preview
stage=$(mktemp -d "$PWD/dist/.preview.XXXXXX")
trap 'rm -rf "$stage"' EXIT
app="$stage/image/KlickSea.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
for arch in arm64 x86_64; do
    swift build -c release --arch "$arch" --scratch-path ".build-release/$arch"
    directory=$(swift build -c release --arch "$arch" --scratch-path ".build-release/$arch" --show-bin-path)
    cp "$directory/KlickSea" "$stage/KlickSea-$arch"
done
lipo -create "$stage/KlickSea-arm64" "$stage/KlickSea-x86_64" -output "$app/Contents/MacOS/KlickSea"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp=none --entitlements Resources/KlickSea.entitlements "$app"
codesign --verify --strict --verbose=2 "$app"
ln -s /Applications "$stage/image/Applications"
cat > "$stage/image/READ ME FIRST.txt" <<'EOF'
KlickSea preview — macOS 15 or later

1. Drag KlickSea.app into Applications, then open it there.
2. This preview uses a local development signature and is NOT notarized.
   If macOS blocks it, open System Settings > Privacy & Security and choose
   Open Anyway for KlickSea, then confirm Open. Do not disable Gatekeeper.
3. KlickSea appears in the menu bar. Open its settings and select a provider.
   Codex requires the Codex CLI installed and logged in.
   Claude requires Claude Code installed and an Anthropic API key (separate billing).
4. Press Control-Shift-4, allow Screen Recording, Microphone and Speech
   Recognition, and ask a question. Relaunch if macOS requests it.

No Xcode, Git, source build or local signing setup is required to install.
The full human microphone flow and installation on another Mac remain unverified.
Captured images and transcribed questions are sent to your selected provider.

Setup: https://docs.klicksea.techsavvyash.dev/getting-started
Providers: https://docs.klicksea.techsavvyash.dev/providers
Source: https://github.com/techsavvyash/klicksea
EOF
dmg="$PWD/dist/preview/KlickSea-$version-preview-universal.dmg"
[[ ! -e "$dmg" ]] || { echo "Preview already exists: $dmg" >&2; exit 1; }
hdiutil create -volname 'KlickSea Preview' -srcfolder "$stage/image" -format UDZO "$dmg"
codesign --sign "$SIGNING_IDENTITY" --timestamp=none "$dmg"
codesign --verify --verbose=2 "$dmg"
(cd dist/preview && shasum -a 256 "$(basename "$dmg")" > "$(basename "$dmg").sha256")
echo "Preview only, not notarized: $dmg"
