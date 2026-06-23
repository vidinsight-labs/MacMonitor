import Foundation
import IOKit

/// Fan ve sıcaklık verisi toplar (SMC üzerinden).
///
/// Not: Fan/sıcaklık verisi `AppleSMC` servisinden okunur — `AppleSmartBattery` yalnızca
/// pil verisi sağlar, fan/sıcaklık anahtarı içermez.
///
/// SMC anahtarları (TC0P/TC0D, F0Ac/F0Mn/F0Mx) **Intel** Mac'lerde çalışır. Apple Silicon'da
/// bu anahtarlar çoğunlukla bulunmaz (ve Apple Silicon MacBook Air'lerde fan yoktur); bu durumda
/// değerler "okunamadı" olarak gösterilir, sahte değer üretilmez.
///
/// Her 3 saniyede bir `Timer` ile güncellenir.
final class FanMonitor: ObservableObject {

    // MARK: - Yayınlanan durum

    @Published private(set) var fans: [FanData] = []
    @Published private(set) var cpuTemperature: Double?   // °C
    @Published private(set) var gpuTemperature: Double?   // °C (yoksa nil)
    @Published private(set) var temperatures: [TempReading] = []   // okunabilen tüm sensörler
    @Published private(set) var smcAvailable = false

    /// Denenecek SMC sıcaklık anahtarları (Intel). Apple Silicon'da çoğu bulunmaz.
    private static let tempSensors: [(key: String, label: String)] = [
        ("TC0P", "CPU (yakın)"),
        ("TC0D", "CPU (çekirdek)"),
        ("TG0P", "GPU (yakın)"),
        ("TG0D", "GPU (çekirdek)"),
        ("TA0P", "Ortam"),
        ("Ts0P", "Yüzey"),
        ("TB0T", "Pil"),
        ("TM0P", "Bellek"),
        ("TH0P", "Depolama (SSD)"),
        ("TW0P", "Wi-Fi")
    ]

    // MARK: - Özel

    private let interval: TimeInterval = 3.0
    private var timer: Timer?
    private var connection: io_connect_t = 0
    private let queue = DispatchQueue(label: "com.macmonitor.fanmonitor.smc")

    // MARK: - Yaşam döngüsü

    init() {
        smcAvailable = openSMC()
        start()
    }

    deinit {
        stop()
        closeSMC()
    }

    func start() {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        update()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Güncelleme

    private func update() {
        guard smcAvailable else { return }
        queue.async { [weak self] in
            guard let self else { return }
            let result = self.readAll()
            DispatchQueue.main.async {
                self.fans = result.fans
                self.cpuTemperature = result.cpu
                self.gpuTemperature = result.gpu
                self.temperatures = result.temps
            }
        }
    }

    private func readAll() -> (fans: [FanData], cpu: Double?, gpu: Double?, temps: [TempReading]) {
        var fans: [FanData] = []
        let count = Int(readValue("FNum") ?? 0)
        for i in 0..<max(0, count) {
            let current = readValue("F\(i)Ac") ?? 0
            let minRPM  = readValue("F\(i)Mn") ?? 0
            let maxRPM  = readValue("F\(i)Mx") ?? 0
            fans.append(FanData(index: i,
                                currentRPM: Int(current),
                                minRPM: Int(minRPM),
                                maxRPM: Int(maxRPM)))
        }

        // Okunabilen tüm sıcaklık sensörleri.
        var temps: [TempReading] = []
        for sensor in Self.tempSensors {
            if let value = sane(readValue(sensor.key)) {
                temps.append(TempReading(id: sensor.key, label: sensor.label, celsius: value))
            }
        }

        // CPU: önce proximity (TC0P), yoksa die (TC0D).
        let cpu = readValue("TC0P") ?? readValue("TC0D")
        // GPU: ayrık/entegre GPU sıcaklığı; yoksa nil.
        let gpu = readValue("TG0P") ?? readValue("TG0D")

        return (fans, sane(cpu), sane(gpu), temps)
    }

    /// Sıcaklığı makul aralıkta doğrula (0 / saçma değerleri ele).
    private func sane(_ temp: Double?) -> Double? {
        guard let temp, temp > 0, temp < 130 else { return nil }
        return temp
    }

    // MARK: - SMC bağlantısı

    private func openSMC() -> Bool {
        // kIOMainPortDefault: macOS 12+ (eski kIOMasterPortDefault yerine, kullanımdan kaldırılmamış).
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess
    }

    private func closeSMC() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    // MARK: - SMC anahtar okuma

    /// Bir SMC anahtarını okuyup tipine göre Double'a çevirir.
    private func readValue(_ key: String) -> Double? {
        guard let (type, data) = readKey(key), data.count >= 2 else { return nil }

        switch type {
        case "flt ":   // little-endian 32-bit float (modern Mac'ler)
            let raw = UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[3]) << 24)
            return Double(Float(bitPattern: raw))
        case "fpe2":   // işaretsiz sabit nokta (fan RPM, eski)
            return Double((UInt(data[0]) << 6) + (UInt(data[1]) >> 2))
        case "sp78":   // işaretli sabit nokta (sıcaklık, Intel)
            return Double(Int8(bitPattern: data[0])) + Double(data[1]) / 256.0
        case "ui8 ":
            return Double(data[0])
        case "ui16":
            return Double((UInt16(data[0]) << 8) | UInt16(data[1]))
        case "ui32":
            return Double((UInt32(data[0]) << 24) | (UInt32(data[1]) << 16) | (UInt32(data[2]) << 8) | UInt32(data[3]))
        default:
            return nil
        }
    }

    /// Anahtarın tip kodunu (4 karakter) ve ham byte'larını döndürür.
    private func readKey(_ key: String) -> (type: String, data: [UInt8])? {
        let code = Self.fourCharCode(key)
        guard let info = readKeyInfo(code) else { return nil }

        var input = SMCParamStruct()
        input.key = code
        input.keyInfo.dataSize = info.size
        input.data8 = 5   // SMC_CMD_READ_BYTES

        guard let output = callSMC(&input) else { return nil }

        var tuple = output.bytes
        let bytes = withUnsafeBytes(of: &tuple) { Array($0) }   // 32 byte
        return (Self.typeString(info.type), bytes)
    }

    private func readKeyInfo(_ code: UInt32) -> (size: UInt32, type: UInt32)? {
        var input = SMCParamStruct()
        input.key = code
        input.data8 = 9   // SMC_CMD_READ_KEYINFO
        guard let output = callSMC(&input) else { return nil }
        return (output.keyInfo.dataSize, output.keyInfo.dataType)
    }

    /// IOConnectCallStructMethod sarmalayıcısı (selector = kSMCHandleYPCEvent = 2).
    private func callSMC(_ input: inout SMCParamStruct) -> SMCParamStruct? {
        guard connection != 0 else { return nil }
        var output = SMCParamStruct()
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let result = IOConnectCallStructMethod(connection, 2, &input, inputSize, &output, &outputSize)
        guard result == kIOReturnSuccess, output.result == 0 else { return nil }
        return output
    }

    // MARK: - Yardımcılar (FourCC)

    /// "TC0P" gibi 4 karakteri big-endian UInt32'ye çevirir.
    private static func fourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }

    /// UInt32 tip kodunu okunabilir 4 karaktere çevirir (ör. "flt ").
    private static func typeString(_ type: UInt32) -> String {
        let bytes = [UInt8((type >> 24) & 0xFF),
                     UInt8((type >> 16) & 0xFF),
                     UInt8((type >> 8) & 0xFF),
                     UInt8(type & 0xFF)]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}

// MARK: - SMC veri yapısı
//
// Kernel'in beklediği bellek düzeniyle birebir eşleşmelidir. Düzen, yaygın olarak
// kullanılan SMCKit / osx-cpu-temp referans uygulamalarından alınmıştır.

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    // SMCBytes_t: 32 byte
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
                (0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0)
}
