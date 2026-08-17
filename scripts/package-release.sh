#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/build/Heart Rate Menu.app"
DIST="$ROOT/dist"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")
ARCHIVE="$DIST/Heart-Rate-Menu-$VERSION-macos.zip"

"$ROOT/scripts/build-app.sh" >/dev/null
mkdir -p "$DIST"

# This project has no Developer ID certificate. Ad-hoc signing makes the bundle
# internally consistent; a public notarized build requires a Developer ID account.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$ARCHIVE" "$ARCHIVE.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"

printf '%s\n%s\n' "$ARCHIVE" "$ARCHIVE.sha256"
