import SwiftUI

/// Yardım sayfası — her bölümün ne işe yaradığı ve değerlerin ne zaman değiştiği.
/// Monitörleri izlemez → sürekli yeniden çizilmez (sabit içerik).
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                intro

                topicCard(
                    icon: "gauge.with.dots.needle.bottom.50percent", tint: .gray, title: "Sistem",
                    intro: "Cihazın güç durumunu, ısı kaynaklı performans kısılmasını, disk alanını ve donanım bileşenlerini gösterir.",
                    points: [
                        InfoPoint(heading: "Termal durum (performans kısılması)",
                                  body: "macOS, cihaz çok ısındığında performansı otomatik düşürür (throttling). 'Yüksek/Kritik' görürsen yavaşlama ısı kaynaklıdır; ağır işleri azaltıp cihazı serinletmek hızı geri getirir."),
                        InfoPoint(heading: "Düşük Güç Modu",
                                  body: "Pili korumak için işlemci hızını ve arka plan işlerini kısar. Açıkken performans bilinçli olarak düşüktür."),
                        InfoPoint(heading: "Disk alanı",
                                  body: "Disk dolmaya yaklaşınca (%90+) sistem yavaşlayabilir; yer açmak performansı iyileştirir."),
                        InfoPoint(heading: "Donanım Bileşenleri",
                                  body: "Model, seri no, çip, Wi-Fi/Bluetooth/SSD modülü bilgileri. Sistemden alındığı için 'Bilgileri Getir' butonuna basınca yüklenir (birkaç saniye sürebilir).")
                    ]
                )

                topicCard(
                    icon: "cpu", tint: .blue, title: "İşlemci (CPU)",
                    intro: "İşlemci, cihazındaki tüm hesaplamaları yapar: uygulama kodları, sistem görevleri ve arka plan işleri. Yüzde, çekirdeklerin ne kadar meşgul olduğunu gösterir.",
                    points: [
                        InfoPoint(heading: "Ne zaman yükselir?",
                                  body: "Ağır uygulamalar (video/foto düzenleme, oyun, kod derleme), çok sayıda açık uygulama/sekme, arka plan işleri (Spotlight indeksleme, yedekleme, güncelleme) ve ağır web siteleri yükü artırır."),
                        InfoPoint(heading: "Ne zaman düşer?",
                                  body: "İş bitince, ağır uygulamaları kapatınca ve sistem boşa çıkınca düşer. Boştayken birkaç yüzdede kalması normaldir."),
                        InfoPoint(heading: "Performans (P) ve Verimlilik (E) çekirdekleri",
                                  body: "Apple Silicon'da hafif/arka plan işleri verimlilik çekirdeklerinde, ağır işler performans çekirdeklerinde çalışır. Bu yüzden E çekirdekleri çoğu zaman daha meşgul görünür — normaldir.")
                    ]
                )

                topicCard(
                    icon: "memorychip", tint: .purple, title: "Bellek (RAM)",
                    intro: "Bellek, açık uygulamaların ve dosyaların hızlı erişilen geçici verisini tutar. Diskten çok daha hızlıdır; cihaz kapanınca içeriği silinir.",
                    points: [
                        InfoPoint(heading: "Ne zaman dolar?",
                                  body: "Çok sayıda uygulama/sekme açınca, büyük dosyalarla (video, görsel) çalışınca dolar. macOS boş RAM'i dosya önbelleği olarak da kullanır — 'dolu' görünmesi her zaman kötü değildir."),
                        InfoPoint(heading: "Basınç ne zaman artar?",
                                  body: "Gerçek talep RAM'i aşınca sistem sıkıştırma ve takas (swap, diske yazma) kullanmaya başlar. Sarı/kırmızı basınç yavaşlama işaretidir."),
                        InfoPoint(heading: "Ne zaman boşalır?",
                                  body: "Uygulamaları kapatınca, 'Belleği Temizle' ile inaktif belleği boşaltınca veya cihazı yeniden başlatınca boşalır.")
                    ]
                )

                topicCard(
                    icon: "fanblades", tint: .teal, title: "Fanlar ve Sıcaklık",
                    intro: "Fanlar, işlemci ve diğer parçaları soğutmak için döner. RPM (dakikadaki devir) ne kadar hızlı döndüklerini gösterir.",
                    points: [
                        InfoPoint(heading: "Ne zaman hızlanır?",
                                  body: "İşlemci/GPU ısındığında (ağır iş, uzun süreli yük) fanlar hızlanır ve sıcaklığı düşürür."),
                        InfoPoint(heading: "Fan görünmüyorsa?",
                                  body: "Bazı modeller (ör. Apple Silicon MacBook Air) fansızdır; pasif soğutma kullanır. Ayrıca sıcaklık sensörleri her modelde okunamayabilir.")
                    ]
                )

                topicCard(
                    icon: "list.bullet.rectangle", tint: .green, title: "İşlemler",
                    intro: "Çalışan tüm programları ve sistem süreçlerini listeler; varsayılan olarak en çok CPU kullanana göre sıralanır.",
                    points: [
                        InfoPoint(heading: "Ne işe yarar?",
                                  body: "Hangi uygulamanın CPU veya belleği çok kullandığını görürsün. Üstteki arama ile isme göre filtreleyebilirsin."),
                        InfoPoint(heading: "Bir işlemi nasıl kapatırım?",
                                  body: "Bir süreç çok kaynak tüketiyor ve yanıt vermiyorsa, satıra sağ tıklayıp 'Zorla Kapat' diyebilirsin. (Sistem süreçleri için yönetici izni gerekebilir.)")
                    ]
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Başlık

    private var intro: some View {
        PageHeader(
            icon: "questionmark",
            gradient: [.gray, Color.gray.opacity(0.5)],
            title: "Yardım",
            subtitle: "Sekmelerin anlamı ve değerlerin neden değiştiği."
        )
    }

    // MARK: - Konu kartı

    private func topicCard(icon: String, tint: Color, title: String,
                           intro: String, points: [InfoPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(tint.opacity(0.15)))
                Text(title)
                    .font(.title3.weight(.semibold))
            }

            Text(intro)
                .font(.callout)
                .foregroundStyle(.secondary)

            ForEach(points) { point in
                VStack(alignment: .leading, spacing: 2) {
                    Text(point.heading)
                        .font(.callout.weight(.semibold))
                    Text(point.body)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }
}

#Preview {
    HelpView()
        .frame(width: 640, height: 820)
}
