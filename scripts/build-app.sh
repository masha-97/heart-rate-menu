#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT="$ROOT/build/Heart Rate Menu.app"

cd "$ROOT"
swift build -c release
mkdir -p "$OUTPUT/Contents/MacOS" "$OUTPUT/Contents/Resources"
install -m 0755 "$ROOT/.build/release/HeartRateMenu" "$OUTPUT/Contents/MacOS/HeartRateMenu"
install -m 0644 "$ROOT/Resources/Info.plist" "$OUTPUT/Contents/Info.plist"
printf '%s\n' "$OUTPUT"
