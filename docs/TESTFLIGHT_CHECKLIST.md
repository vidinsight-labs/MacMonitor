# TestFlight Kontrol Listesi — MacMonitor v2.0

## Ön koşullar

- [ ] Apple Developer Program üyeliği aktif
- [ ] App Store Connect'te `com.macmonitor.app` kayıtlı
- [ ] App Group `group.com.macmonitor.app` oluşturuldu
- [ ] Distribution sertifikası ve provisioning profile hazır

## Sandbox doğrulama

- [ ] CPU, bellek, disk metrikleri çalışıyor
- [ ] İşlem listesi görünüyor
- [ ] Process terminate (kullanıcı uygulamaları) çalışıyor
- [ ] Güvenlik taraması Security.framework ile imza okuyor
- [ ] Güvenlik diff — ikinci taramada yeni/kaldırılan öğeler
- [ ] Bellek purge devre dışı mesajı gösteriliyor
- [ ] Fan/SMC fallback mesajı (Apple Silicon'da beklenen)
- [ ] Yük olayları kaydediliyor ve timeline görünüyor
- [ ] Akıllı öneriler Overview ve menü çubuğunda
- [ ] Widget CPU/RAM güncelleniyor
- [ ] Shortcuts: Sağlık kontrolü, güvenlik taraması, top işlemler

## TestFlight yükleme

```bash
xcodegen generate
xcodebuild -project MacMonitor.xcodeproj -scheme MacMonitor -configuration Release archive -archivePath build/MacMonitor.xcarchive
# Organizer veya xcodebuild -exportArchive ile App Store Connect'e yükle
```

## Beta test notları (testçilere)

- İlk güvenlik taraması baseline oluşturur; ikinci taramada diff görünür
- Widget için uygulamayı bir kez açıp kapatın (veri paylaşımı)
- Bildirimler için Sistem Ayarları'ndan izin verin
