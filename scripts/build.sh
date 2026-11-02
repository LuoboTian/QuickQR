#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/QuickQR.app/Contents/MacOS
cache="build/module-cache-$(printf '%s' "$PWD" | shasum | cut -c1-12)"
mkdir -p "$cache"
xcrun swiftc -swift-version 5 -module-cache-path "$cache" -target "$(uname -m)-apple-macosx13.0" Sources/QR.swift Sources/Library.swift Sources/main.swift -o build/QuickQR.app/Contents/MacOS/QuickQR
cp Info.plist build/QuickQR.app/Contents/Info.plist
codesign --force --sign - build/QuickQR.app
touch build/QuickQR.app
printf 'Built: %s/build/QuickQR.app\n' "$PWD"
