#!/bin/bash
# MacMonitor — Release .app derler ve dağıtılabilir bir .dmg üretir.
# Kullanım:  ./scripts/build-dmg.sh [sürüm]   (varsayılan sürüm: 1.0)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0}"
BUILD_DIR="$(pwd)/build/release"
APP="$BUILD_DIR/MacMonitor.app"
STAGING="$(pwd)/build/dmg-staging"
DMG="$(pwd)/MacMonitor-$VERSION.dmg"

echo "▸ Release derleniyor…"
xcodebuild -project MacMonitor.xcodeproj -target MacMonitor -configuration Release \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" build >/dev/null

echo "▸ DMG hazırlanıyor…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"        # sürükle-bırak için Applications kısayolu

hdiutil create -volname "MacMonitor" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "✅ Hazır: $DMG"
