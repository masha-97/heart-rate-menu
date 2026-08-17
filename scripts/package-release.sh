#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/build/Heart Rate Menu.app"
DIST="$ROOT/dist"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")
ARCHIVE="$DIST/Heart-Rate-Menu-$VERSION-macos.zip"
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/heart-rate-menu-package.XXXXXX")
PACKAGE_ROOT="$STAGING/Heart-Rate-Menu-$VERSION-macos"

cleanup() {
    rm -rf "$STAGING"
}
trap cleanup EXIT INT TERM

"$ROOT/scripts/build-app.sh" >/dev/null
mkdir -p "$DIST"

# This project has no Developer ID certificate. Ad-hoc signing makes the bundle
# internally consistent; a public notarized build requires a Developer ID account.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$ARCHIVE" "$ARCHIVE.sha256"
mkdir -p "$PACKAGE_ROOT"
ditto "$APP" "$PACKAGE_ROOT/Heart Rate Menu.app"
install -m 0644 "$ROOT/docs/INSTALL-zh-CN.txt" "$PACKAGE_ROOT/安装说明.txt"
ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_ROOT" "$ARCHIVE"
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"

printf '%s\n%s\n' "$ARCHIVE" "$ARCHIVE.sha256"
