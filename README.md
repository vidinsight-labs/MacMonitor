<div align="center">

<h1>MacMonitor</h1>

<p><strong>Mac'inizin nabzını tutun.</strong></p>

<p>
Yerel macOS sistem monitörü — gerçek zamanlı metrikler, akıllı öneriler,<br>
menü çubuğu widget'ı, macOS Widget ve Shortcuts desteği.
</p>

<p>
  <a href="https://github.com/vidinsight-labs/MacMonitor/releases"><img src="https://img.shields.io/badge/⬇%20İndir-v3.0-007AFF?style=for-the-badge" alt="Download v3.0" /></a>
</p>

<p>
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Sürüm-3.0-blue?style=flat-square" alt="Version 3.0" />
  <img src="https://img.shields.io/badge/Dil-TR%20%7C%20EN-34C759?style=flat-square" alt="TR / EN" />
  <img src="https://img.shields.io/badge/App%20Store-hazır-purple?style=flat-square" alt="App Store ready" />
</p>

<p>
  <a href="#nedir">Nedir?</a> ·
  <a href="#yeni-v3">v3</a> ·
  <a href="#özellikler">Özellikler</a> ·
  <a href="#kurulum">Kurulum</a> ·
  <a href="#sınırlar">Sınırlar</a>
</p>

</div>

---

## Nedir?

MacMonitor, *"Bilgisayarım iyi mi?"*, *"Neden yavaşladı?"*, *"Açılışta ne çalışıyor?"* sorularına yanıt veren **yerel** bir macOS uygulamasıdır.

Tüm veriler cihazınızda kalır — bulut yok, hesap yok, API anahtarı yok. Pencereyi kapatsanız bile menü çubuğundan CPU ve bellek durumunu izleyebilir; kritik anlarda bildirim alırsınız.

**Türkçe / İngilizce** arayüz; dil anında değiştirilebilir.

---

## Yeni v3

| v3'te gelen | Açıklama |
|-------------|----------|
| **Gelişmiş yük olayları** | Süre, tepe/ortalama CPU, genişletilebilir detay, 7 günlük özet |
| **Yük zaman çizelgesi** | 30 günlük grafik + günlük olay sayısı |
| **Çekirdek grid** | Sabit 4 sütun düzeni |
| **Dil seçici** | Sidebar'da yenilenen TR/EN toggle |
| **Branding** | Yardım sayfasında powered by vidinsight |

v2'den devralınan: Akıllı öneriler, macOS Widget, Shortcuts/Siri, güvenlik diff, App Store sandbox altyapısı.

---

## Özellikler

### Genel Bakış
Tek bakışta sistem sağlığı — iyi / dikkat / kritik.

- Metrik kartları: İşlemci, Bellek, Fanlar, Disk (tıklanabilir)
- Sorunlu uygulamayı adıyla gösteren **Dikkat** uyarıları
- **Akıllı Öneriler** — uptime, disk, bellek, CPU kuralları
- **Mac'imi Kontrol Et** sağlık taraması

### İşlemci
- Çekirdek başına kullanım (P/E ayrımı, Apple Silicon)
- Sabit **4 sütun** çekirdek grid'i
- 60 saniyelik canlı grafik
- **Yük olayları** — CPU %80+ anları; süre, tepe, ortalama, suçlu uygulamalar (1 ay)
- **Yük zaman çizelgesi** — 30 gün grafik, günlük olay sayısı

### Bellek
- Aktif / sabitlenmiş / sıkıştırılmış / boş dağılımı
- Bellek basıncı, swap, uptime
- Bellek temizleme *(App Store dışı / tam yetkili build)*

### Fanlar & Sıcaklık
- Fan RPM ve SMC sensörleri *(Intel Mac, sandbox dışı)*
- Termal durum göstergesi

### Sistem
- Termal kısılma, Düşük Güç Modu, pil/güç
- Disk alanı, donanım envanteri (model, çip, Wi-Fi/BT/SSD)

### Güvenlik Bakışı
Antivirüs değil — şeffaflık aracı.

- Açılış öğeleri (LaunchAgents / Daemons)
- Kod imzası durumu (Apple / geliştirici / imzasız)
- **Güvenlik diff** — baseline karşılaştırma, yeni/kaldırılan öğeler

### İşlemler
- CPU ve belleğe göre sıralama, arama, ikonlar
- Zorla kapat *(kullanıcı uygulamaları)*

### Menü Çubuğu
- CPU/RAM çubukları + en çok kullanan 3 uygulama
- Akıllı öneri özeti
- Arka planda çalışır

### Bildirimler
CPU, bellek, disk veya ısı kritik seviyede **1 dk+** kalırsa uyarır (30 dk cooldown).

### macOS Widget
Notification Center'da sağlık + CPU/RAM özeti *(imzalı build gerekir)*.

### Shortcuts / Siri
- Sistem sağlığını kontrol et
- Güvenlik taraması yap
- En çok kaynak tüketen işlemler

---

## Kurulum

### App Store *(önerilen)*
Mac App Store'dan indirin — otomatik güncelleme, imzalı Widget/Shortcuts.

### DMG (manuel)
1. [Releases](https://github.com/vidinsight-labs/MacMonitor/releases) → `MacMonitor-3.0.dmg`
2. **Applications**'a sürükleyin
3. İlk açılış: **Sağ tık → Aç → Aç**

> **Gereksinim:** macOS 13 (Ventura) veya üzeri

### Kaynaktan derleme

```bash
git clone https://github.com/vidinsight-labs/MacMonitor.git
cd MacMonitor
xcodegen generate          # gerekirse
open MacMonitor.xcodeproj  # Cmd+R
```

App Store imzası için `Config/Local.xcconfig` → `DEVELOPMENT_TEAM = ...`

---

## Sınırlar

<details>
<summary><strong>App Store sandbox</strong></summary>

| Özellik | App Store | Tam yetkili build |
|---------|:---------:|:-----------------:|
| CPU, bellek, bildirimler | ✅ | ✅ |
| Widget, Shortcuts | ✅ | ✅ |
| Akıllı öneriler, güvenlik diff | ✅ | ✅ |
| Bellek purge | ❌ | ✅ |
| Fan/SMC (çoğu Mac) | ❌ | Kısmen |
| Uygulama bazlı CPU (bazı uygulamalar) | Kısmen | ✅ |

Sandbox'ta uygulama CPU'su okunamazsa yük olayları **"Toplam sistem yükü"** olarak kaydedilir.

</details>

<details>
<summary><strong>Apple Silicon</strong></summary>

M1/M2/M3 Mac'lerde fan/SMC sensörleri okunamaz. Termal kısılma, pil, disk ve diğer özellikler normal çalışır.

</details>

---

## Geliştirici

```bash
./scripts/build-dmg.sh 3.0     # DMG üret
./scripts/archive-appstore.sh  # App Store archive
```

Belgeler: [`docs/YENI_OZELLIKLER.md`](docs/YENI_OZELLIKLER.md) · [`docs/APP_STORE_SUBMIT.md`](docs/APP_STORE_SUBMIT.md)

---

<div align="center">

<br>

**MacMonitor v3.0** · Swift & SwiftUI

<br>

<a href="https://github.com/vidinsight-labs/MacMonitor">vidinsight-labs/MacMonitor</a>

<br><br>

powered by [vidinsight-labs](https://github.com/vidinsight-labs)

</div>
