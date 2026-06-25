#!/bin/bash
# MacMonitor — App Store / TestFlight archive ve yükleme.
#
# Ön koşullar:
#   1. Apple Developer Program üyeliği
#   2. Config/Local.xcconfig içinde DEVELOPMENT_TEAM (Local.xcconfig.example'dan kopyala)
#   3. Xcode'da Apple hesabıyla giriş + "Apple Distribution" sertifikası
#   4. App Store Connect'te com.macmonitor.app kayıtlı
#
# Kullanım:
#   ./scripts/archive-appstore.sh           # archive + export (IPA benzeri .pkg)
#   ./scripts/archive-appstore.sh --upload  # archive + doğrudan App Store Connect'e yükle
set -euo pipefail
cd "$(dirname "$0")/.."

UPLOAD=false
if [[ "${1:-}" == "--upload" ]]; then
  UPLOAD=true
fi

if [[ ! -f Config/Local.xcconfig ]]; then
  echo "❌ Config/Local.xcconfig bulunamadı."
  echo "   cp Config/Local.xcconfig.example Config/Local.xcconfig"
  echo "   Dosyada DEVELOPMENT_TEAM = <Team ID> ayarlayın."
  exit 1
fi

TEAM_ID=$(grep DEVELOPMENT_TEAM Config/Local.xcconfig | head -1 | sed 's/.*= *//')
if [[ -z "$TEAM_ID" || "$TEAM_ID" == "YOUR_TEAM_ID" ]]; then
  echo "❌ Config/Local.xcconfig içinde geçerli DEVELOPMENT_TEAM yok."
  exit 1
fi

ARCHIVE_PATH="build/MacMonitor.xcarchive"
EXPORT_PATH="build/appstore-export"
EXPORT_PLIST="Config/ExportOptions-appstore.plist"

echo "▸ Xcode projesi üretiliyor (xcodegen)…"
xcodegen generate

echo "▸ Release archive (Team: $TEAM_ID)…"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p build

xcodebuild \
  -project MacMonitor.xcodeproj \
  -scheme MacMonitor \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=macOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  archive

if $UPLOAD; then
  echo "▸ App Store Connect'e yükleniyor…"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates
  echo "✅ Yükleme tamamlandı. App Store Connect → TestFlight'tan build'i seçin."
else
  echo "▸ App Store paketi dışa aktarılıyor…"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "Config/ExportOptions-export.plist" \
    -allowProvisioningUpdates
  echo "✅ Archive: $ARCHIVE_PATH"
  echo "✅ Export:  $EXPORT_PATH"
  echo ""
  echo "TestFlight için: ./scripts/archive-appstore.sh --upload"
  echo "veya Xcode → Organizer → Distribute App"
fi
