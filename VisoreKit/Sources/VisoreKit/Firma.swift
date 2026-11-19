import Foundation

public enum Firma {

    public static func scadenza(profilo dati: Data) -> Date? {
        guard let inizio = dati.range(of: Data("<?xml".utf8)),
              let fine = dati.range(of: Data("</plist>".utf8), in: inizio.lowerBound..<dati.endIndex),
              let elenco = try? PropertyListSerialization.propertyList(
                  from: dati.subdata(in: inizio.lowerBound..<fine.upperBound), format: nil) as? [String: Any]
        else { return nil }
        return elenco["ExpirationDate"] as? Date
    }

    public static func scadenza(bundle: Bundle = .main) -> Date? {
        guard let dove = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let dati = try? Data(contentsOf: dove) else { return nil }
        return scadenza(profilo: dati)
    }

    public static func giorni(fino scade: Date, da adesso: Date = Date(), calendario: Calendar = .current) -> Int {
        let oggi = calendario.startOfDay(for: adesso)
        let quel = calendario.startOfDay(for: scade)
        return calendario.dateComponents([.day], from: oggi, to: quel).day ?? 0
    }

    public static func aParole(fino scade: Date, da adesso: Date = Date(), calendario: Calendar = .current) -> String {
        if scade <= adesso { return "La firma è scaduta: rinnovala con AltStore." }
        switch giorni(fino: scade, da: adesso, calendario: calendario) {
        case ...0: return "La firma scade oggi: rinnovala con AltStore."
        case 1: return "La firma scade domani."
        case let n: return "La firma scade fra \(n) giorni."
        }
    }
}
