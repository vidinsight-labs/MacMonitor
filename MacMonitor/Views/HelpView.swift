import SwiftUI

/// Yardım sayfası — her bölümün ne işe yaradığı ve değerlerin ne zaman değiştiği.
/// Monitörleri izlemez → sürekli yeniden çizilmez (sabit içerik).
struct HelpView: View {
    @ObservedObject private var loc = Localizer.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                intro

                topicCard(
                    icon: "square.grid.2x2.fill", tint: .blue, title: t("Genel Bakış", "Overview"),
                    intro: t("Açılış sayfası. Bilgisayarının genel durumunu tek bakışta, sade dille özetler: işlemci, bellek, sıcaklık ve disk için anlık durum.", "The home page. It sums up your computer's overall condition at a glance in plain language: the current state of the processor, memory, temperature and disk."),
                    points: [
                        InfoPoint(heading: t("Üstteki renkli yargı", "The colored verdict at the top"),
                                  body: t("Yeşil = her şey normal, turuncu = bir şeyler yükseldi ama kritik değil, kırmızı = en az bir değer kritik. Aşağıdaki 'Dikkat' bölümü neyin sorun olduğunu ve ne yapabileceğini söyler.", "Green = everything is normal, orange = something has risen but isn't critical, red = at least one value is critical. The 'Attention' section below tells you what the problem is and what you can do about it.")),
                        InfoPoint(heading: t("Dört kart (tıklanabilir)", "Four cards (clickable)"),
                                  body: t("İşlemci, Bellek, Sıcaklık ve Disk kartlarına tıklayınca o konunun detay sayfasına geçersin.", "Tapping the Processor, Memory, Temperature or Disk cards takes you to that topic's detail page.")),
                        InfoPoint(heading: t("Dikkat bölümü", "Attention section"),
                                  body: t("Bir değer yükseldiğinde, çoğu zaman buna yol açan uygulamayı adıyla gösterir (ör. 'Chrome işlemciyi %180 kullanıyor') ve kısa bir öneri verir.", "When a value rises, it usually names the app responsible (e.g. 'Chrome is using 180% of the processor') and gives a short suggestion.")),
                        InfoPoint(heading: t("Sağlık Taraması", "Health Scan"),
                                  body: t("'Mac'imi Kontrol Et' butonu işlemci, bellek, disk, sıcaklık, pil ve güvenliği tek seferde kontrol edip madde madde bir yapılacaklar listesi çıkarır. Her satıra tıklayınca ilgili sayfaya geçersin.", "The 'Check My Mac' button inspects the processor, memory, disk, temperature, battery and security all at once and produces an itemized to-do list. Tapping any row takes you to the relevant page.")),
                        InfoPoint(heading: t("Bildirimler", "Notifications"),
                                  body: t("'Kritik durumda beni uyar' açıkken; işlemci, bellek, disk veya ısı bir süre (yaklaşık 1 dk) kritik seviyede kalırsa, uygulama kapalı/arka planda olsa bile bir bildirim gönderir. Aynı uyarı 30 dakikada bir tekrarlanır (spam olmaması için).", "When 'Alert me on critical conditions' is on, if the processor, memory, disk or temperature stays at a critical level for a while (about 1 minute), the app sends a notification even if it's closed or in the background. The same alert repeats every 30 minutes (to avoid spam)."))
                    ]
                )

                topicCard(
                    icon: "gauge.with.dots.needle.bottom.50percent", tint: .gray, title: t("Sistem", "System"),
                    intro: t("Cihazın güç durumunu, ısı kaynaklı performans kısılmasını, disk alanını ve donanım bileşenlerini gösterir.", "Shows your device's power state, heat-driven performance throttling, disk space and hardware components."),
                    points: [
                        InfoPoint(heading: t("Termal durum (performans kısılması)", "Thermal state (performance throttling)"),
                                  body: t("macOS, cihaz çok ısındığında performansı otomatik düşürür (throttling). 'Yüksek/Kritik' görürsen yavaşlama ısı kaynaklıdır; ağır işleri azaltıp cihazı serinletmek hızı geri getirir.", "macOS automatically reduces performance when the device gets too hot (throttling). If you see 'High/Critical', the slowdown is heat-related; cutting back on heavy tasks and letting the device cool down restores its speed.")),
                        InfoPoint(heading: t("Düşük Güç Modu", "Low Power Mode"),
                                  body: t("Pili korumak için işlemci hızını ve arka plan işlerini kısar. Açıkken performans bilinçli olarak düşüktür.", "To save battery, it limits processor speed and background activity. While it's on, performance is intentionally lower.")),
                        InfoPoint(heading: t("Disk alanı", "Disk space"),
                                  body: t("Disk dolmaya yaklaşınca (%90+) sistem yavaşlayabilir; yer açmak performansı iyileştirir.", "As the disk nears full (90%+), the system can slow down; freeing up space improves performance.")),
                        InfoPoint(heading: t("Pil Sağlığı (dizüstüde)", "Battery Health (on laptops)"),
                                  body: t("Maksimum kapasite (yeni pile göre şu an tutabildiği en yüksek şarj), şarj döngü sayısı ve durum. Bu değerler Apple'ın 'Ayarlar > Pil'de gösterdiğiyle aynıdır. Kapasite zamanla düşer; %80 altı ve yüksek döngü sayısı pilin yaşlandığını gösterir.", "Maximum capacity (the highest charge it can currently hold compared to a new battery), charge cycle count and condition. These values match what Apple shows under 'Settings > Battery'. Capacity drops over time; below 80% and a high cycle count indicate the battery is aging.")),
                        InfoPoint(heading: t("Yer Aç", "Free Up Space"),
                                  body: t("'Diski Tara' ile en çok yer kaplayan klasörleri (Çöp, İndirilenler, Uygulamalar, Önbellek…) boyutlarıyla görürsün. Çöp kutusunu onayla boşaltabilir, diğer klasörleri Finder'da açıp elle gözden geçirebilirsin. Kişisel dosyaların asla otomatik silinmez.", "With 'Scan Disk' you can see the folders taking up the most space (Trash, Downloads, Applications, Cache…) along with their sizes. You can empty the Trash after confirming, and open other folders in Finder to review them by hand. Your personal files are never deleted automatically.")),
                        InfoPoint(heading: t("Donanım Bileşenleri", "Hardware Components"),
                                  body: t("Model, seri no, çip, Wi-Fi/Bluetooth/SSD modülü bilgileri. Sistemden alındığı için 'Bilgileri Getir' butonuna basınca yüklenir (birkaç saniye sürebilir).", "Model, serial number, chip, and Wi-Fi/Bluetooth/SSD module details. Because this is read from the system, it loads when you press the 'Fetch Info' button (which can take a few seconds)."))
                    ]
                )

                topicCard(
                    icon: "cpu", tint: .blue, title: t("İşlemci (CPU)", "Processor (CPU)"),
                    intro: t("İşlemci, cihazındaki tüm hesaplamaları yapar: uygulama kodları, sistem görevleri ve arka plan işleri. Yüzde, çekirdeklerin ne kadar meşgul olduğunu gösterir.", "The processor does all the computation on your device: app code, system tasks and background jobs. The percentage shows how busy the cores are."),
                    points: [
                        InfoPoint(heading: t("Ne zaman yükselir?", "When does it go up?"),
                                  body: t("Ağır uygulamalar (video/foto düzenleme, oyun, kod derleme), çok sayıda açık uygulama/sekme, arka plan işleri (Spotlight indeksleme, yedekleme, güncelleme) ve ağır web siteleri yükü artırır.", "Heavy apps (video/photo editing, games, compiling code), lots of open apps/tabs, background jobs (Spotlight indexing, backups, updates) and demanding websites all increase the load.")),
                        InfoPoint(heading: t("Ne zaman düşer?", "When does it go down?"),
                                  body: t("İş bitince, ağır uygulamaları kapatınca ve sistem boşa çıkınca düşer. Boştayken birkaç yüzdede kalması normaldir.", "It drops once the work is done, when you close heavy apps, and when the system goes idle. Sitting at a few percent while idle is normal.")),
                        InfoPoint(heading: t("Performans (P) ve Verimlilik (E) çekirdekleri", "Performance (P) and Efficiency (E) cores"),
                                  body: t("Apple Silicon'da hafif/arka plan işleri verimlilik çekirdeklerinde, ağır işler performans çekirdeklerinde çalışır. Bu yüzden E çekirdekleri çoğu zaman daha meşgul görünür — normaldir.", "On Apple Silicon, light/background work runs on the efficiency cores and heavy work runs on the performance cores. That's why the E cores often look busier — and that's normal."))
                    ]
                )

                topicCard(
                    icon: "memorychip", tint: .purple, title: t("Bellek (RAM)", "Memory (RAM)"),
                    intro: t("Bellek, açık uygulamaların ve dosyaların hızlı erişilen geçici verisini tutar. Diskten çok daha hızlıdır; cihaz kapanınca içeriği silinir.", "Memory holds the fast-access temporary data of open apps and files. It's far faster than the disk, and its contents are wiped when the device shuts down."),
                    points: [
                        InfoPoint(heading: t("Ne zaman dolar?", "When does it fill up?"),
                                  body: t("Çok sayıda uygulama/sekme açınca, büyük dosyalarla (video, görsel) çalışınca dolar. macOS boş RAM'i dosya önbelleği olarak da kullanır — 'dolu' görünmesi her zaman kötü değildir.", "It fills up when you open lots of apps/tabs and work with large files (video, images). macOS also uses free RAM as a file cache — so looking 'full' isn't always a bad thing.")),
                        InfoPoint(heading: t("Basınç ne zaman artar?", "When does pressure rise?"),
                                  body: t("Gerçek talep RAM'i aşınca sistem sıkıştırma ve takas (swap, diske yazma) kullanmaya başlar. Sarı/kırmızı basınç yavaşlama işaretidir.", "When real demand exceeds the RAM, the system starts using compression and swap (writing to disk). Yellow/red pressure is a sign of slowdown.")),
                        InfoPoint(heading: t("Ne zaman boşalır?", "When does it free up?"),
                                  body: t("Uygulamaları kapatınca, 'Belleği Temizle' ile inaktif belleği boşaltınca veya cihazı yeniden başlatınca boşalır.", "It frees up when you close apps, release inactive memory with 'Clear Memory', or restart the device."))
                    ]
                )

                topicCard(
                    icon: "fanblades", tint: .teal, title: t("Fanlar ve Sıcaklık", "Fans and Temperature"),
                    intro: t("Fanlar, işlemci ve diğer parçaları soğutmak için döner. RPM (dakikadaki devir) ne kadar hızlı döndüklerini gösterir.", "The fans spin to cool the processor and other parts. RPM (revolutions per minute) shows how fast they're spinning."),
                    points: [
                        InfoPoint(heading: t("Ne zaman hızlanır?", "When do they speed up?"),
                                  body: t("İşlemci/GPU ısındığında (ağır iş, uzun süreli yük) fanlar hızlanır ve sıcaklığı düşürür.", "When the CPU/GPU heats up (heavy work, sustained load), the fans spin faster to bring the temperature down.")),
                        InfoPoint(heading: t("Fan görünmüyorsa?", "What if no fan appears?"),
                                  body: t("Bazı modeller (ör. Apple Silicon MacBook Air) fansızdır; pasif soğutma kullanır. Ayrıca sıcaklık sensörleri her modelde okunamayabilir.", "Some models (e.g. the Apple Silicon MacBook Air) are fanless and use passive cooling. Also, temperature sensors can't be read on every model."))
                    ]
                )

                topicCard(
                    icon: "lock.shield", tint: .indigo, title: t("Güvenlik Bakışı", "Security Overview"),
                    intro: t("Açılışta veya arka planda sessizce çalışan öğeleri (LaunchAgents/Daemons) ve her birinin kod imzası durumunu gösterir. Bu bir antivirüs değildir — şeffaflık aracıdır.", "Shows the items that run silently at startup or in the background (LaunchAgents/Daemons) and the code-signing status of each. This isn't an antivirus — it's a transparency tool."),
                    points: [
                        InfoPoint(heading: t("Neden önemli?", "Why does it matter?"),
                                  body: t("Mac'teki reklam/zararlı yazılımlar çoğu zaman 'açılışta otomatik çalış' diye buraya tutunur. Apple bu listeyi kullanıcıya açıkça göstermez.", "Adware/malware on a Mac often latches on here so it can 'run automatically at startup'. Apple doesn't show this list to users in plain sight.")),
                        InfoPoint(heading: t("İmza durumu ne demek?", "What does signing status mean?"),
                                  body: t("'Apple imzalı' ve 'İmzalı · [geliştirici]' güvenilir kaynaklardır. 'İmzasız' veya 'tuhaf konum' (ör. /tmp) işareti, öğenin tanımlı bir geliştiriciye ait olmadığını gösterir — zararlı olduğu anlamına gelmez, ama tanımıyorsan araştırman için bir uyarıdır.", "'Signed by Apple' and 'Signed · [developer]' are trusted sources. An 'Unsigned' or 'unusual location' (e.g. /tmp) flag means the item doesn't belong to an identified developer — it doesn't mean it's malicious, but it's a heads-up to investigate if you don't recognize it.")),
                        InfoPoint(heading: t("Sınırı", "Its limits"),
                                  body: t("Gerçek koruma macOS'un yerleşik Gatekeeper/XProtect'idir. Bu bölüm onların yerini almaz; yalnızca 'Mac'imde sessizce ne kurulu?' sorusunu yanıtlar.", "Real protection comes from macOS's built-in Gatekeeper/XProtect. This section doesn't replace them; it only answers the question 'what's silently installed on my Mac?'"))
                    ]
                )

                topicCard(
                    icon: "list.bullet.rectangle", tint: .green, title: t("İşlemler", "Processes"),
                    intro: t("Çalışan tüm programları ve sistem süreçlerini listeler; varsayılan olarak en çok CPU kullanana göre sıralanır.", "Lists every running program and system process; by default they're sorted by which uses the most CPU."),
                    points: [
                        InfoPoint(heading: t("Ne işe yarar?", "What is it for?"),
                                  body: t("Hangi uygulamanın CPU veya belleği çok kullandığını görürsün. Üstteki arama ile isme göre filtreleyebilirsin.", "You can see which app is using a lot of CPU or memory. Use the search field at the top to filter by name.")),
                        InfoPoint(heading: t("Bir işlemi nasıl kapatırım?", "How do I quit a process?"),
                                  body: t("Bir süreç çok kaynak tüketiyor ve yanıt vermiyorsa, satıra sağ tıklayıp 'Zorla Kapat' diyebilirsin. (Sistem süreçleri için yönetici izni gerekebilir.)", "If a process is consuming a lot of resources and not responding, you can right-click its row and choose 'Force Quit'. (Administrator permission may be required for system processes.)"))
                    ]
                )
            }
            .padding(20)
            .centeredPageContent()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Başlık

    private var intro: some View {
        PageHeader(
            icon: "questionmark",
            gradient: [.gray, Color.gray.opacity(0.5)],
            title: t("Yardım", "Help"),
            subtitle: t("Sekmelerin anlamı ve değerlerin neden değiştiği.", "What the tabs mean and why the values change.")
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
