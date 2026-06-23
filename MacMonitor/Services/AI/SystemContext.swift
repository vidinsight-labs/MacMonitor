import Foundation

/// Anlık sistem durumunu (CPU/bellek/işlemler/termal/disk/yük olayları) AI'ya
/// verilecek kompakt bir metne çevirir. Yalnızca zaten toplanmış veriyi okur.
enum SystemContext {

    @MainActor
    static func snapshot() -> String {
        let m = SystemMonitors.shared
        var lines: [String] = []

        // CPU
        let cpu = m.cpu
        let model = cpu.modelName.isEmpty ? "İşlemci" : cpu.modelName
        lines.append("CPU: \(model), \(cpu.coreCount) çekirdek, toplam kullanım %\(Int(cpu.totalUsage.rounded()))")
        if !cpu.cores.isEmpty {
            let perCore = cpu.cores.map { "Ç\($0.id):%\(Int($0.usage.rounded()))" }.joined(separator: " ")
            lines.append("Çekirdekler: \(perCore)")
        }

        // Bellek
        let mem = m.memory.memory
        if mem.total > 0 {
            let pct = Int(Double(mem.used) / Double(mem.total) * 100)
            lines.append("Bellek: \(gb(mem.used)) / \(gb(mem.total)) kullanımda (%\(pct)), basınç: \(m.memory.pressure.label)")
            if mem.swapTotal > 0 {
                lines.append("Takas (swap): \(gb(mem.swapUsed)) / \(gb(mem.swapTotal))")
            }
        }

        // Açık kalma süresi (uzun süre → yeniden başlatma değerlendirilebilir)
        let uptime = Int(ProcessInfo.processInfo.systemUptime)
        lines.append("Cihaz açık kalma süresi: \(uptime / 86_400) gün \((uptime % 86_400) / 3_600) saat")

        // Güç & termal
        lines.append("Termal durum: \(thermalLabel(m.systemInfo.thermalState)); Düşük Güç Modu: \(m.systemInfo.lowPowerMode ? "açık" : "kapalı")")
        if let level = m.systemInfo.batteryLevel {
            lines.append("Güç: \(m.systemInfo.powerSource), pil %\(level)\(m.systemInfo.batteryCharging ? " (şarj oluyor)" : "")")
        }
        if m.systemInfo.diskTotal > 0 {
            let freePct = Int((Double(m.systemInfo.diskFree) / Double(m.systemInfo.diskTotal) * 100).rounded())
            lines.append(String(format: "Disk: %.0f GB boş / %.0f GB toplam (%%%d boş)",
                                Double(m.systemInfo.diskFree) / 1_000_000_000,
                                Double(m.systemInfo.diskTotal) / 1_000_000_000,
                                freePct))
        }

        // En çok CPU kullanan işlemler
        let top = Array(m.process.processes.prefix(8))
        if !top.isEmpty {
            lines.append("En çok CPU kullanan işlemler:")
            for p in top {
                lines.append("  - \(p.name): %\(String(format: "%.1f", p.cpuUsage)) CPU, \(gb(p.memoryUsage)) bellek")
            }
        }

        // Son yüksek yük olayları
        let events = Array(m.loadEvents.events.prefix(3))
        if !events.isEmpty {
            lines.append("Son yüksek yük (riskli) olayları:")
            for e in events {
                let culprits = e.culprits.map { "\($0.name) %\(Int($0.cpu.rounded()))" }.joined(separator: ", ")
                lines.append("  - tepe %\(Int(e.peak.rounded())): \(culprits.isEmpty ? "bilgi yok" : culprits)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func gb(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    private static func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "normal"
        case .fair:     return "hafif ısınma"
        case .serious:  return "yüksek (sistem performansı düşürüyor)"
        case .critical: return "kritik"
        @unknown default: return "bilinmiyor"
        }
    }
}
