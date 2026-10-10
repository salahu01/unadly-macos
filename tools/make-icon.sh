#!/bin/bash
# Builds Resources/AppIcon.icns from Resources/AppIcon.png (1024x1024, artwork inside
# Apple's icon grid with a transparent margin). AppIcon.svg is the editable source.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Resources/AppIcon.png"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$SRC" --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$SRC" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$ROOT/Resources/AppIcon.icns"
cp "$ROOT/Resources/AppIcon.png" "$ROOT/docs/icon.png"
echo "==> Resources/AppIcon.icns"
