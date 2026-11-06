#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-$PWD/build/Keep Awake.app}"
mkdir -p "$app/Contents/MacOS"
swiftc -O -target "$(uname -m)-apple-macosx13.0" Sources/main.swift Sources/MovementSchedule.swift -o "$app/Contents/MacOS/Keep Awake" -framework AppKit -framework ApplicationServices
cp Info.plist "$app/Contents/Info.plist"
# A stable ad-hoc signature helps macOS identify the app for Accessibility permission.
codesign --force --sign - "$app"
printf 'Built %s\n' "$app"
