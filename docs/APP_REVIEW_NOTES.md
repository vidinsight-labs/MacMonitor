# App Review Notes — MacMonitor v2.0

## Uygulama özeti

MacMonitor is a **local system monitor** (not antivirus, not cleaner). It displays CPU, memory, disk, process list, and startup item transparency. All data stays on device.

## Entitlements

- **App Sandbox:** Required for Mac App Store
- **App Groups (`group.com.macmonitor.app`):** Share CPU/RAM health snapshot with Widget extension only
- **files.user-selected.read-only:** Not actively used in v2.0; reserved for future folder picker

## Özellik kısıtlamaları (bilinçli)

| Özellik | Durum | Açıklama |
|---------|-------|----------|
| Memory purge | Disabled | Requires admin shell; replaced with restart recommendation |
| Fan/SMC IOKit | Limited | May not work in sandbox; thermal state via ProcessInfo shown instead |
| Process list | Limited | Sandbox: user apps via NSWorkspace; system processes hidden |
| Empty Trash | Disabled | Sandbox restriction; user directed to Finder |

## Güvenlik taraması

- Scans `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons`
- Uses Security.framework for code signature (not shell codesign)
- **Not malware detection** — transparency tool only

## Shortcuts / App Intents

- SystemHealthIntent: reads local widget snapshot
- SecurityScanIntent: triggers in-app scan
- TopProcessesIntent: reads local process list

## Privacy

- No network calls
- No analytics
- Privacy manifest: PrivacyInfo.xcprivacy included
- Policy: docs/PRIVACY_POLICY.md

## Test hesabı

Not required — app works without login.

## İletişim

Support: https://github.com/vidinsight-labs/MacMonitor/issues
