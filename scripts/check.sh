#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/checks
# No XCTest dependency: works with Apple's Command Line Tools alone.
swiftc -D STANDALONE_CHECKS -swift-version 5 -parse-as-library -module-cache-path "$PWD/.build/checks/module-cache" \
    Sources/KlickSea/Provider.swift Sources/KlickSea/Capture.swift \
    Tests/KlickSeaTests/CoreChecks.swift -o .build/checks/core-checks
.build/checks/core-checks
plutil -lint Resources/Info.plist Resources/KlickSea.entitlements
bash -n scripts/build-app.sh scripts/notarize.sh
