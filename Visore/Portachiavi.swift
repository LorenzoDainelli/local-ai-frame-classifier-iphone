import Foundation
import LocalAuthentication
import Security

enum Portachiavi {
    static let servizio = "visore.forziere"
    static let conto = "password"
    static let segnalibro = "visore.cartella"

    static func salva(password: String, cartella: URL?) {
        guard let controllo = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, nil) else { return }
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: servizio,
                                   kSecAttrAccount as String: conto]
        SecItemDelete(base as CFDictionary)
        var nuovo = base
        nuovo[kSecValueData as String] = Data(password.utf8)
        nuovo[kSecAttrAccessControl as String] = controllo
        guard SecItemAdd(nuovo as CFDictionary, nil) == errSecSuccess else { return }
        if let dati = try? cartella?.bookmarkData() {
            UserDefaults.standard.set(dati, forKey: segnalibro)
        }
    }

    static var c_e: Bool { UserDefaults.standard.data(forKey: segnalibro) != nil }

    static func cartella() -> URL? {
        guard let dati = UserDefaults.standard.data(forKey: segnalibro) else { return nil }
        var vecchio = false
        return try? URL(resolvingBookmarkData: dati, bookmarkDataIsStale: &vecchio)
    }

    static func leggi() -> String? {
        let contesto = LAContext()
        contesto.localizedReason = "Apri l'archivio"
        let domanda: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                      kSecAttrService as String: servizio,
                                      kSecAttrAccount as String: conto,
                                      kSecReturnData as String: true,
                                      kSecUseAuthenticationContext as String: contesto]
        var risultato: CFTypeRef?
        guard SecItemCopyMatching(domanda as CFDictionary, &risultato) == errSecSuccess,
              let dati = risultato as? Data else { return nil }
        return String(data: dati, encoding: .utf8)
    }

    static func dimentica() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: servizio] as CFDictionary)
        UserDefaults.standard.removeObject(forKey: segnalibro)
    }
}
