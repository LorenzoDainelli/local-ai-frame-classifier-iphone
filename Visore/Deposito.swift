import Foundation

enum Deposito {
    static var documenti: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var interna: URL { documenti.appendingPathComponent("Pacchetto", isDirectory: true) }

    static var arrivo: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pacchetto.in-arrivo", isDirectory: true)
    }

    static var cartellaRitorno: URL { documenti.appendingPathComponent("Ritorno", isDirectory: true) }

    static func ritorno(prova: Bool) -> URL {
        prepara()
        return cartellaRitorno.appendingPathComponent(prova ? "prova.db" : "ritorno.db")
    }

    static func prepara() {
        let fm = FileManager.default
        let vecchia = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pacchetto", isDirectory: true)
        if fm.fileExists(atPath: vecchia.path), !fm.fileExists(atPath: interna.path) {
            try? fm.moveItem(at: vecchia, to: interna)
        }
        for cartella in [interna, cartellaRitorno] {
            try? fm.createDirectory(at: cartella, withIntermediateDirectories: true)
            fuoriDalBackup(cartella)
        }
    }

    static func fuoriDalBackup(_ cartella: URL) {
        var valori = URLResourceValues()
        valori.isExcludedFromBackup = true
        var dove = cartella
        try? dove.setResourceValues(valori)
    }

    static var c_e: Bool {
        FileManager.default.fileExists(atPath: interna.appendingPathComponent("visore.json").path)
    }

    static var dalCavo: Bool {
        FileManager.default.fileExists(atPath: interna.appendingPathComponent(".cavo.json").path)
    }

    static var completo: Bool {
        guard let dati = try? Data(contentsOf: interna.appendingPathComponent("visore.json")),
              let carta = try? JSONSerialization.jsonObject(with: dati) as? [String: Any] else { return false }
        return carta["stato"] as? String == "completo"
    }

    static var inArrivo: Bool {
        guard !completo else { return false }
        let fm = FileManager.default
        if dalCavo || fm.fileExists(atPath: interna.appendingPathComponent("visore.json").path) { return true }
        let dentro = (try? fm.contentsOfDirectory(atPath: interna.path)) ?? []
        return !dentro.isEmpty
    }

    static func serveAggiornare(da sorgente: URL) -> Bool {
        guard let nuova = try? Data(contentsOf: sorgente.appendingPathComponent("visore.json")) else { return false }
        let vecchia = try? Data(contentsOf: interna.appendingPathComponent("visore.json"))
        return nuova != vecchia
    }

    static func importa(da sorgente: URL) throws -> URL {
        let fm = FileManager.default
        let nuova = arrivo
        try fm.createDirectory(at: nuova.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.removeItem(at: nuova)
        var errore: NSError?
        var fallito: Error?
        NSFileCoordinator().coordinate(readingItemAt: sorgente, options: [], error: &errore) { letta in
            do { try fm.copyItem(at: letta, to: nuova) } catch { fallito = error }
        }
        if let e = errore ?? fallito {
            try? fm.removeItem(at: nuova)
            throw e
        }
        return nuova
    }

    static func sostituisci(con nuova: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: interna.path) {
            _ = try fm.replaceItemAt(interna, withItemAt: nuova)
        } else {
            try fm.moveItem(at: nuova, to: interna)
        }
        fuoriDalBackup(interna)
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: interna.path)
    }

    static func proteggi() {
        let fm = FileManager.default
        guard completo, !inArrivo,
              let giro = fm.enumerator(at: interna, includingPropertiesForKeys: [.fileProtectionKey]) else { return }
        for case let dove as URL in giro {
            let adesso = try? dove.resourceValues(forKeys: [.fileProtectionKey]).fileProtection
            if adesso != .complete {
                try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: dove.path)
            }
        }
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: interna.path)
        fuoriDalBackup(interna)
    }

    static func scarta(_ nuova: URL) { try? FileManager.default.removeItem(at: nuova) }
}
