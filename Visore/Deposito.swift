import Foundation

enum Deposito {
    static var interna: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pacchetto", isDirectory: true)
    }

    static var c_e: Bool {
        FileManager.default.fileExists(atPath: interna.appendingPathComponent("visore.json").path)
    }

    static func serveAggiornare(da sorgente: URL) -> Bool {
        guard let nuova = try? Data(contentsOf: sorgente.appendingPathComponent("visore.json")) else { return false }
        let vecchia = try? Data(contentsOf: interna.appendingPathComponent("visore.json"))
        return nuova != vecchia
    }

    static func importa(da sorgente: URL) throws -> URL {
        let fm = FileManager.default
        let base = interna.deletingLastPathComponent()
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        let nuova = base.appendingPathComponent("Pacchetto.in-arrivo", isDirectory: true)
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
        var valori = URLResourceValues()
        valori.isExcludedFromBackup = true
        var dove = interna
        try? dove.setResourceValues(valori)
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: interna.path)
    }

    static func scarta(_ nuova: URL) { try? FileManager.default.removeItem(at: nuova) }
}
