<div align="center">

<h1>MacMonitor</h1>

<p><strong>Mac'inizin nabzını tutun.</strong></p>

<p>
MacMonitor, Mac'inizin işlemci, bellek, fan, disk ve güvenlik durumunu<br>
canlı izleyen yerel bir macOS uygulamasıdır.<br>
Menü çubuğundan hızlı bakış; tam pencerede detaylı analiz.
</p>

<p>
  <a href="https://github.com/vidinsight-labs/MacMonitor/releases"><img src="https://img.shields.io/badge/⬇%20İndir-DMG-007AFF?style=for-the-badge" alt="Download DMG" /></a>
</p>

<p>
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Dil-TR%20%7C%20EN-34C759?style=flat-square" alt="TR / EN" />
</p>

<p>
  <a href="#nedir">Nedir?</a> ·
  <a href="#özellikler">Özellikler</a> ·
  <a href="#kurulum">Kurulum</a>
</p>

</div>

---

## Nedir?

MacMonitor, *"Bilgisayarım iyi mi?"*, *"Neden yavaşladı?"*, *"Açılışta ne çalışıyor?"* gibi sorulara yanıt vermek için tasarlandı.

Uygulama arka planda çalışır — pencereyi kapatsanız bile menü çubuğundan CPU ve bellek durumunu görebilirsiniz. Bir sorun oluştuğunda sizi uyarır, hangi uygulamanın kaynak tükettiğini gösterir.

**Türkçe ve İngilizce** arayüz desteklenir; dil anında değiştirilebilir.

---

## Özellikler

### Genel Bakış
Açılış sayfasında bilgisayarınızın anlık durumunu tek bakışta görürsünüz.

- Sistem sağlığı yargısı: iyi / dikkat / kritik
- İşlemci, bellek, fan ve disk metrik kartları
- Sorun varsa hangi uygulamanın sorumlu olduğunu gösteren uyarılar
- Kartlara tıklayarak detay sayfasına geçiş

### İşlemci
- Anlık ve çekirdek başına CPU kullanımı
- Apple Silicon'da performans / verimlilik çekirdek ayrımı
- Son 60 saniyelik kullanım grafiği
- Yüksek yük anlarını kaydetme (son 1 ay, hangi uygulama sorumlu)

### Bellek
- Aktif, sabitlenmiş, sıkıştırılmış ve boş bellek dağılımı
- Bellek baskısı ve takas (swap) kullanımı
- Ne kadar süredir açık olduğu ve yeniden başlatma önerisi
- Tek tıkla bellek temizleme

### Fanlar & Sıcaklık
- Fan hızı (RPM) ve sıcaklık sensörleri *(Intel Mac'lerde)*
- Termal durum göstergesi

### Sistem
- Performans kısılması (ısı nedeniyle yavaşlama) durumu
- Düşük Güç Modu, pil ve güç bilgisi
- Disk doluluk oranı
- Mac modeli, çip, seri numarası, Wi-Fi / Bluetooth / SSD bilgileri

### Güvenlik Bakışı
Antivirüs değildir — açılışta arka planda çalışan öğeleri şeffaf biçimde listeler.

- Açılışta otomatik başlayan uygulamalar ve servisler
- Her öğenin imza durumu (Apple, geliştirici veya imzasız)
- Şüpheli konum uyarıları

### İşlemler
- Çalışan tüm uygulamaları CPU ve belleğe göre listeleme
- Anlık arama ve uygulama ikonları
- İstenmeyen uygulamayı zorla kapatma (onaylı)

### Menü Çubuğu
Pencere kapalıyken bile menü çubuğundan:

- CPU ve bellek kullanım çubukları
- En çok kaynak tüketen 3 uygulama
- Ana pencereyi açma düğmesi

### Bildirimler
CPU, bellek, disk veya sıcaklık uzun süre kritik seviyede kalırsa sizi uyarır. Anlık sıçramalar değil, gerçek sorunlar için — spam koruması vardır.

---

## Kurulum

1. [Releases](https://github.com/vidinsight-labs/MacMonitor/releases) sayfasından `MacMonitor-x.y.dmg` dosyasını indirin
2. DMG'yi açın, **MacMonitor**'u **Applications** klasörüne sürükleyin
3. Uygulamayı açın — ilk seferde uyarı çıkarsa **Sağ tık → Aç → Aç**

> **Gereksinim:** macOS 13 (Ventura) veya üzeri

<details>
<summary><strong>Apple Silicon notu</strong></summary>
<br>

M1/M2/M3 Mac'lerde fan hızı ve SMC sıcaklık sensörleri okunamaz (Apple'ın donanım kısıtı). Diğer tüm özellikler — CPU, bellek, işlemler, bildirimler, güvenlik — normal çalışır.

</details>

---

<div align="center">

<br>

<a href="https://github.com/vidinsight-labs/MacMonitor">vidinsight-labs/MacMonitor</a>

</div>
