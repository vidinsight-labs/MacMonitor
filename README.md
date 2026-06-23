# MacMonitor

Yerel (native) bir macOS sistem monitörü. İşlemci, bellek, fan/sıcaklık, çalışan
işlemler ve genel sistem durumunu canlı izler; ayrıca **Groq destekli bir AI
asistanı** ile sistemini gerçek verilere dayanarak analiz eder.

> Swift 5 · SwiftUI · MVVM · minimum **macOS 13.0**

---

## Özellikler

- **İşlemci** — çekirdek başına kullanım (Performans/Verimlilik ayrımı), toplam yük, 60 sn'lik geçmiş grafiği (Swift Charts), CPU + Mac modeli.
- **Bellek** — aktif/sabitlenmiş/sıkıştırılmış/boş dağılımı, basınç, takas (swap), açık kalma süresi + yeniden başlatma önerisi, "Belleği Temizle" (purge).
- **Fanlar & Sıcaklık** — fan RPM ve SMC sıcaklık sensörleri, termal durum, fan kontrol arayüzü *(yalnızca Intel; Apple Silicon'da SMC anahtarları okunamaz)*.
- **İşlemler** — sıralanabilir tablo (CPU/Bellek), arama, uygulama ikonları, **Zorla Kapat** (onaylı).
- **Sistem** — termal kısılma durumu, Düşük Güç Modu, pil/güç, disk alanı, donanım bileşenleri (model, seri no, çip, Wi-Fi/Bluetooth/SSD — butonla).
- **AI Asistan** — kendi **Groq** API anahtarınla; gerçek sistem durumunu bağlam alıp Türkçe teşhis/öneri verir.
- **Yük Olayları** — CPU eşiği aştığında o anı + sorumlu işlemleri kaydeder (son 1 ay, diske kalıcı).

Tüm sayfalar koyu/açık moda uyumlu ortak bir tasarım dili paylaşır.

---

## Kullanıcı kurulumu (DMG)

1. Releases'tan `MacMonitor-x.y.dmg` dosyasını indir, çift tıkla.
2. **MacMonitor**'u açılan pencerede **Applications**'a sürükle.
3. İlk açılışta uyarı çıkarsa: uygulamaya **sağ tık → Aç**.

> Uygulama ad-hoc imzalıdır; imzasız/notarize edilmemiş dağıtımda macOS Gatekeeper
> ilk açılışta uyarır (sağ tık → Aç ile geçilir). Geniş dağıtım için Apple Developer
> ID imzası + notarization gerekir.

---

## Kaynaktan derleme

Xcode projesi `project.yml`'den **XcodeGen** ile üretilir (depoda tutulmaz).

```bash
git clone <repo-url>
cd macbook-monitor

brew install xcodegen        # bir kez
xcodegen generate            # MacMonitor.xcodeproj üretir
open MacMonitor.xcodeproj    # Xcode'da aç → Cmd+R
```

Gereksinimler: **macOS 13+**, **Xcode 15+** (tam Xcode; sadece Command Line Tools yetmez).

---

## DMG üretme

```bash
./scripts/build-dmg.sh        # MacMonitor-1.0.dmg üretir
./scripts/build-dmg.sh 1.2    # sürüm belirterek
```

Betik Release derler, `MacMonitor.app` + Applications kısayolunu paketler ve
sıkıştırılmış bir `.dmg` çıkarır.

---

## AI Asistan kurulumu

1. [console.groq.com](https://console.groq.com) adresinden **ücretsiz API anahtarı** al.
2. Uygulamada **Asistan** sekmesi → anahtarı yapıştır → **Kaydet**.
3. **Bağlan** → önerilen model otomatik seçilir (örn. `llama-3.3-70b-versatile`).
4. **Sistemimi Analiz Et** veya serbest soru sor.

- Anahtar yalnızca **macOS Keychain**'de saklanır (depoya/diske düz metin yazılmaz).
- Soru sorulduğunda işlem ve sistem verisi seçilen modele (Groq) gönderilir — opt-in.

---

## Proje yapısı

```
macbook-monitor/
├── MacMonitor/
│   ├── App/          # Giriş noktası, AppDelegate (menü bar), SystemMonitors (paylaşılan)
│   ├── Models/       # Veri yapıları (CPUData, MemoryData, FanData, ProcessData, LoadEvent)
│   ├── Monitors/     # Veri toplama: sysctl / mach / IOKit (SMC) / libproc
│   ├── Services/AI/  # KeychainStore, GroqClient, AIAssistant, SystemContext
│   ├── Views/        # SwiftUI ekranları + DesignSystem (ortak kart/başlık/gösterge)
│   └── Resources/    # entitlements
├── scripts/
│   └── build-dmg.sh  # Release derler + .dmg üretir
├── project.yml       # XcodeGen proje tanımı (KAYNAK — .xcodeproj bundan üretilir)
└── README.md
```

**Mimari:** MVVM. Her monitör bir `ObservableObject`'tir ve tek bir `SystemMonitors`
konteynerinde paylaşılır; hem ana pencere hem menü bar aynı örnekleri kullanır
(çift veri toplama yok). Veriler her 2–5 sn'de bir `Timer` ile güncellenir.

---

## Bilinen sınırlar

- **Apple Silicon'da fan/sıcaklık/CPU frekansı SMC ile okunamaz** (Intel anahtarları yok); bu metrikler "okunamadı/yok" gösterir. Termal kısılma durumu, pil ve disk ise `ProcessInfo`/IOKit ile çalışır.
- **Sandbox kapalıdır** (SMC erişimi, `purge` ve ağ için gerekli) → App Store'a uygun değildir; doğrudan dağıtım içindir.
- **Zorla Kapat** yalnızca kendi süreçlerinde çalışır; sistem süreçleri yetki gerektirir.
- AI Türkçe kalitesi seçilen Groq modeline bağlıdır (büyük modeller belirgin daha iyi).

---

## Lisans

Bir lisans dosyası ekleyerek (örn. MIT) kullanım koşullarını belirtebilirsin.
