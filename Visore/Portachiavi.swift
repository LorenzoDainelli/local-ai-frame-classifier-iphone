import Foundation
import LocalAuthentication
import Security

enum Lettura {
    case password(String)
    case fallita
    case annullata
    case assente
}

enum Portachiavi {
    static let servizio = "visore.forziere"
    static let conto = "password"
    static let segnalibro = "visore.cartella"
    static let scritta = "visore.password.scritta"
    static let avvio = "visore.password.avvio"
    static let fallimenti = "visore.faceid.fallimenti"
    static let durata: TimeInterval = 7 * 24 * 60 * 60
    static let fallimentiMassimi = 5

    static var avvioDelTelefono: Date {
        Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)
    }

    static func salva(password: String, cartella: URL?) {
        guard let controllo = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, nil) else { return }
        dimenticaPassword()
        var nuovo = base
        nuovo[kSecValueData as String] = Data(password.utf8)
        nuovo[kSecAttrAccessControl as String] = controllo
        guard SecItemAdd(nuovo as CFDictionary, nil) == errSecSuccess else { return }
        let d = UserDefaults.standard
        d.set(Date(), forKey: scritta)
        d.set(avvioDelTelefono, forKey: avvio)
        d.set(0, forKey: fallimenti)
        if let dati = try? cartella?.bookmarkData() {
            d.set(dati, forKey: segnalibro)
        }
    }

    static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: servizio,
         kSecAttrAccount as String: conto]
    }

    static var c_e: Bool { UserDefaults.standard.object(forKey: scritta) != nil }

    static func scaduta(adesso: Date = Date(), avvioOra: Date = avvioDelTelefono) -> Bool {
        let d = UserDefaults.standard
        guard let quando = d.object(forKey: scritta) as? Date,
              let avvioAllora = d.object(forKey: avvio) as? Date else { return true }
        if adesso.timeIntervalSince(quando) >= durata || adesso < quando { return true }
        if abs(avvioOra.timeIntervalSince(avvioAllora)) > 120 { return true }
        return d.integer(forKey: fallimenti) >= fallimentiMassimi
    }

    static func cartella() -> URL? {
        guard let dati = UserDefaults.standard.data(forKey: segnalibro) else { return nil }
        var vecchio = false
        return try? URL(resolvingBookmarkData: dati, bookmarkDataIsStale: &vecchio)
    }

    static func leggi() -> Lettura {
        guard !scaduta() else {
            dimenticaPassword()
            return .assente
        }
        let contesto = LAContext()
        contesto.localizedReason = "Apri l'archivio"
        contesto.localizedFallbackTitle = ""
        var domanda = base
        domanda[kSecReturnData as String] = true
        domanda[kSecUseAuthenticationContext as String] = contesto
        var risultato: CFTypeRef?
        let esito = SecItemCopyMatching(domanda as CFDictionary, &risultato)
        switch esito {
        case errSecSuccess:
            guard let dati = risultato as? Data, let testo = String(data: dati, encoding: .utf8) else {
                dimenticaPassword()
                return .assente
            }
            UserDefaults.standard.set(0, forKey: fallimenti)
            return .password(testo)
        case errSecAuthFailed:
            let d = UserDefaults.standard
            d.set(d.integer(forKey: fallimenti) + 1, forKey: fallimenti)
            if d.integer(forKey: fallimenti) >= fallimentiMassimi { dimenticaPassword() }
            return .fallita
        case errSecUserCanceled, errSecInteractionNotAllowed:
            return .annullata
        default:
            dimenticaPassword()
            return .assente
        }
    }

    static func dimenticaPassword() {
        SecItemDelete(base as CFDictionary)
        let d = UserDefaults.standard
        d.removeObject(forKey: scritta)
        d.removeObject(forKey: avvio)
    }

    static func dimentica() {
        dimenticaPassword()
        UserDefaults.standard.removeObject(forKey: segnalibro)
        UserDefaults.standard.set(0, forKey: fallimenti)
    }
}
