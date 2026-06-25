# App Store'a Gönderim Rehberi — MacMonitor v2.0

Bu rehber, MacMonitor'u Mac App Store'da yayınlamak için gereken adımları sırayla listeler.

## Bireysel (Individual) hesapla yayınlama

Şirket hesabına gerek yok. **Apple Developer Program — Individual** ($99/yıl) ile tek başına yayınlayabilirsin.

| | Bireysel (Individual) | Şirket (Organization) |
|--|------------------------|------------------------|
| Kayıt | [developer.apple.com](https://developer.apple.com/programs/) → Individual | Organization + D-U-N-S numarası |
| App Store'da görünen ad | **Senin adın** (ör. Taha Çağatay İnce) | Şirket unvanı |
| Team ID | Hesabına özel tek Team ID | Şirketin Team ID'si |
| App Store yükleme | Evet | Evet |

**Önemli ayrımlar:**

1. **Ücretsiz "Personal Team"** (sadece Xcode hesabı) → yalnızca kendi Mac'inde test. **App Store'a yükleyemezsin.**
2. **Ücretli Individual Program** ($99) → TestFlight + App Store. İhtiyacın olan bu.
3. Xcode'da birden fazla "Team" görüyorsan (işveren, eski projeler vb.) **bireysel üyeliğine ait Team'i** seç. Şirket Team ID'sini `Local.xcconfig`'e yazma.

### Bireysel hesap kurulumu

1. [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/) → **Start your enrollment** → **Individual**
2. Apple ID ile giriş, kimlik / ödeme ($99/yıl)
3. Onay sonrası [App Store Connect](https://appstoreconnect.apple.com) aynı Apple ID ile açılır
4. Xcode → **Settings → Accounts** → aynı Apple ID → altında **Individual** team görünür
5. Team ID: hesabına tıkla → **Team ID** (10 karakter, örn. `57AMC77JG9`)

`Config/Local.xcconfig`:

```
DEVELOPMENT_TEAM = 57AMC77JG9
```

(Buraya **kendi** Individual Team ID'ni yaz; örnekler kişisel değil.)

App Store Connect'te uygulama oluştururken **Company Name** alanı yoktur; mağazada **geliştirici adı olarak senin adın** listelenir.

---

## 1. Apple Developer hesabı

1. [Apple Developer Program](https://developer.apple.com/programs/) üyeliğiniz aktif olmalı (yıllık $99).
2. [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**
   - Platform: **macOS**
   - Name: **MacMonitor**
   - Bundle ID: **com.macmonitor.app** (önce [Identifiers](https://developer.apple.com/account/resources/identifiers/list) bölümünde oluşturun)
   - SKU: `macmonitor` (serbest metin)

## 2. App Group (Widget için)

[Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+** → **App Groups**

- Identifier: `group.com.macmonitor.app`

Ardından **com.macmonitor.app** ve **com.macmonitor.app.widget** App ID'lerine bu App Group'u ekleyin.

## 3. Yerel imzalama ayarı

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

`Config/Local.xcconfig` dosyasını düzenleyin (bireysel Individual Team ID):

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

Team ID: Xcode → Settings → Accounts → **Individual** hesabın → Team ID.

**Şirket team'i değil**, kendi adına kayıtlı Individual team olmalı.

Xcode'da bir kez **Signing & Capabilities** açıp otomatik imzalamanın çalıştığını doğrulayın (Distribution profili oluşur).

## 4. Archive ve TestFlight yükleme

```bash
chmod +x scripts/archive-appstore.sh
./scripts/archive-appstore.sh --upload
```

İlk çalıştırmada Xcode Apple Distribution sertifikası ve provisioning profile oluşturabilir; onay isteyebilir.

Alternatif (GUI):

1. `xcodegen generate && open MacMonitor.xcodeproj`
2. Scheme: **MacMonitor** → **Any Mac**
3. **Product → Archive**
4. Organizer → **Distribute App** → **App Store Connect** → **Upload**

## 5. App Store Connect metadata

Aşağıdakileri App Store Connect'te doldurun. Metin taslakları: [APP_STORE_METADATA.md](APP_STORE_METADATA.md)

| Alan | Değer |
|------|-------|
| Privacy Policy URL | https://github.com/vidinsight-labs/MacMonitor/blob/main/docs/PRIVACY_POLICY.md |
| Support URL | https://github.com/vidinsight-labs/MacMonitor/issues |
| Kategori | Utilities |
| Fiyat | Ücretsiz |
| Yaş | 4+ |
| ITSAppUsesNonExemptEncryption | Hayır (Info.plist'te zaten NO) |

### Ekran görüntüleri (en az 1, önerilen 6)

1280×800 veya 1440×900 macOS ekran görüntüsü:

1. Genel Bakış (akıllı öneriler)
2. İşlemci + yük zaman çizelgesi
3. Güvenlik diff
4. Widget (Notification Center)
5. Menü çubuğu popover
6. Bellek sayfası

## 6. App Review notları

Gönderim sırasında **App Review Information → Notes** alanına [APP_REVIEW_NOTES.md](APP_REVIEW_NOTES.md) içeriğini yapıştırın.

Önemli noktalar:

- Antivirüs değil, yerel sistem monitörü
- Sandbox kısıtları: işlem listesi kullanıcı uygulamalarıyla sınırlı
- Bellek purge ve çöp kutusu sandbox'ta kapalı

## 7. TestFlight → Production

1. App Store Connect → **TestFlight** → build işlendikten sonra (5–30 dk)
2. **Internal Testing** ile kendiniz test edin ([TESTFLIGHT_CHECKLIST.md](TESTFLIGHT_CHECKLIST.md))
3. Sorun yoksa **App Store** sekmesi → **+ Version** → build seç → **Submit for Review**

## 8. Sık karşılaşılan hatalar

| Hata | Çözüm |
|------|--------|
| No signing certificate "Apple Distribution" | Xcode → Settings → Accounts → Manage Certificates → **+** Apple Distribution |
| Provisioning profile doesn't match | `DEVELOPMENT_TEAM` doğru mu; App Group portalda tanımlı mı |
| Missing app icon | `MacMonitor/Resources/Assets.xcassets/AppIcon` mevcut olmalı |
| Invalid bundle | Bundle ID Connect ile eşleşmeli: `com.macmonitor.app` |

## Hızlı kontrol listesi

- [ ] Developer Program aktif
- [ ] App Store Connect'te uygulama kaydı
- [ ] App Group `group.com.macmonitor.app`
- [ ] `Config/Local.xcconfig` + Team ID
- [ ] `./scripts/archive-appstore.sh --upload` başarılı
- [ ] Ekran görüntüleri yüklendi
- [ ] Gizlilik politikası URL'si girildi
- [ ] TestFlight testi tamam
- [ ] Submit for Review
