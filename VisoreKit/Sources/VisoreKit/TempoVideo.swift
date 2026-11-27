import Foundation

public enum TempoVideo {

    public static func passato(_ secondi: Double) -> String {
        let centesimi = secondi.isFinite ? Int((max(0, secondi) * 100 + 1e-6).rounded(.down)) : 0
        let s = centesimi / 100
        return String(format: "%02d:%02d,%02d", s / 60, s % 60, centesimi % 100)
    }

    public static func manca(_ secondi: Double) -> String {
        let s = secondi.isFinite ? Int(max(0, (secondi - 1e-6).rounded(.up))) : 0
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
