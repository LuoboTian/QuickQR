#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
cache="build/module-cache-$(printf '%s' "$PWD" | shasum | cut -c1-12)"
mkdir -p "$cache"
xcrun swiftc -swift-version 5 -module-cache-path "$cache" Sources/QR.swift Sources/Library.swift Tests/main.swift -o build/qr-tests
build/qr-tests

/usr/bin/python3 - <<'PYTEST'
import plistlib
with open('Info.plist', 'rb') as f:
    info = plistlib.load(f)
service = info['NSServices'][0]
assert 'NSRequiredContext' in service, 'Service must opt in to menu presentation'
assert service['NSRequiredContext'] == {}
assert service['NSMessage'] == 'generateQRCode'
assert 'public.utf8-plain-text' in service['NSSendTypes']
print('PASS: Services declaration/menu visibility regression checks')
PYTEST
xcrun swiftc -swift-version 5 -module-cache-path "$cache" Sources/WindowHost.swift Tests/Window/main.swift -o build/window-tests
build/window-tests
