import Foundation
import SQLite3

public struct Cuore: Hashable {
    public let impronta: String
    public let messoIl: String?

    public init(impronta: String, messoIl: String?) {
        self.impronta = impronta
        self.messoIl = messoIl
    }
}

public struct Raccolta: Identifiable, Hashable {
    public var id: Int64 { numero }
    public let numero: Int64
    public let nome: String
    public let creataIl: String?
    public let impronte: [String]

    public init(numero: Int64, nome: String, creataIl: String?, impronte: [String]) {
        self.numero = numero
        self.nome = nome
        self.creataIl = creataIl
        self.impronte = impronte
    }
}

public struct Scorta: Equatable {
    public let cuori: [Cuore]
    public let tolti: [Cuore]
    public let raccolte: [Raccolta]

    public init(cuori: [Cuore] = [], tolti: [Cuore] = [], raccolte: [Raccolta] = []) {
        self.cuori = cuori
        self.tolti = tolti
        self.raccolte = raccolte
    }
}

public enum ErroreRitorno: Error, Equatable {
    case nonScritto
    case nonSpostato
    case nomeVuoto
}

public final class Ritorno {

    public static let posto = "ritorno.db"

    static let schema = [
        "CREATE TABLE IF NOT EXISTS informazioni (chiave TEXT PRIMARY KEY, valore TEXT NOT NULL)",
        "CREATE TABLE IF NOT EXISTS cuori (impronta TEXT PRIMARY KEY, messo_il TEXT)",
        "CREATE TABLE IF NOT EXISTS raccolte (id INTEGER PRIMARY KEY, nome TEXT NOT NULL, creata_il TEXT)",
        "CREATE TABLE IF NOT EXISTS raccolte_scatti (raccolta_id INTEGER NOT NULL, impronta TEXT NOT NULL, "
            + "PRIMARY KEY (raccolta_id, impronta))",
        "CREATE TABLE IF NOT EXISTS diario (aperto_il TEXT PRIMARY KEY, durata_s INTEGER, "
            + "latitudine REAL, longitudine REAL, quante_foto INTEGER)",
    ]

    static let illeggibile = "Quello che avevi messo da parte su questo iPhone non si rilegge più. "
        + "Riparto da quello che il computer sapeva all'ultimo travaso, e il file che non si legge "
        + "l'ho spostato accanto senza cancellarlo. Le foto non c'entrano e ci sono tutte."

    public let dove: URL
    public private(set) var guaio: String?
    private let chiave: Chiave
    private var db: OpaquePointer?

    public init(dove: URL, chiave: Chiave, scorta: Scorta) throws {
        self.dove = dove
        self.chiave = chiave
        var daRifare = true
        var dati: Data?
        if FileManager.default.fileExists(atPath: dove.path) {
            do {
                dati = try chiave.decifra(Data(contentsOf: dove), posto: Ritorno.posto)
                daRifare = false
            } catch {
                try Ritorno.mettiDaParte(dove)
                guaio = Ritorno.illeggibile
            }
        }
        if let dati {
            do {
                try apri(dati)
            } catch {
                sqlite3_close(db)
                db = nil
                try Ritorno.mettiDaParte(dove)
                guaio = Ritorno.illeggibile
                daRifare = true
                try apri(nil)
            }
        } else {
            try apri(nil)
        }
        for comando in Ritorno.schema { try esegui(comando) }
        var cambiato = false
        if daRifare { cambiato = try riprendi(scorta) }
        if try applica(scorta.tolti) { cambiato = true }
        if cambiato { try salva() }
    }

    deinit { sqlite3_close(db) }

    public static func adesso(_ quando: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return f.string(from: quando)
    }

    public func cuori() -> Set<String> {
        Set((try? righe("SELECT impronta FROM cuori", []) { $0.testo(0) ?? "" }) ?? [])
    }

    public func cuoriInOrdine() -> [Cuore] {
        (try? righe("SELECT impronta, messo_il FROM cuori ORDER BY messo_il DESC, impronta", []) {
            Cuore(impronta: $0.testo(0) ?? "", messoIl: $0.testo(1))
        }) ?? []
    }

    public func haIlCuore(_ impronta: String) -> Bool {
        ((try? righe("SELECT count(*) FROM cuori WHERE impronta = ?", [impronta]) { $0.intero(0) ?? 0 })?.first ?? 0) > 0
    }

    public func raccolte() -> [Raccolta] {
        let teste = (try? righe("SELECT id, nome, creata_il FROM raccolte ORDER BY creata_il DESC, id DESC", []) {
            ($0.intero(0) ?? 0, $0.testo(1) ?? "", $0.testo(2))
        }) ?? []
        return teste.map { t in
            Raccolta(numero: t.0, nome: t.1, creataIl: t.2,
                     impronte: (try? righe("SELECT impronta FROM raccolte_scatti WHERE raccolta_id = ? ORDER BY impronta",
                                           [t.0]) { $0.testo(0) ?? "" }) ?? [])
        }
    }

    public func raccolta(_ numero: Int64) -> Raccolta? {
        raccolte().first { $0.numero == numero }
    }

    public func metti(_ impronta: String, quando: String = Ritorno.adesso()) throws {
        try metti([impronta], quando: quando)
    }

    public func metti(_ impronte: [String], quando: String = Ritorno.adesso()) throws {
        try cambia {
            for i in impronte {
                try esegui("INSERT INTO cuori (impronta, messo_il) VALUES (?, ?) ON CONFLICT(impronta) DO NOTHING",
                           [i, quando])
            }
        }
    }

    public func togli(_ impronta: String) throws {
        try togli([impronta])
    }

    public func togli(_ impronte: [String]) throws {
        try cambia {
            for i in impronte { try esegui("DELETE FROM cuori WHERE impronta = ?", [i]) }
        }
    }

    @discardableResult
    public func nuovaRaccolta(_ nome: String, impronte: [String] = [],
                              quando: String = Ritorno.adesso()) throws -> Int64 {
        let pulito = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pulito.isEmpty else { throw ErroreRitorno.nomeVuoto }
        var numero: Int64 = 0
        try cambia {
            try esegui("INSERT INTO raccolte (nome, creata_il) VALUES (?, ?)", [pulito, quando])
            numero = sqlite3_last_insert_rowid(db)
            for i in impronte {
                try esegui("INSERT INTO raccolte_scatti (raccolta_id, impronta) VALUES (?, ?) "
                           + "ON CONFLICT(raccolta_id, impronta) DO NOTHING", [numero, i])
            }
        }
        return numero
    }

    public func rinomina(_ numero: Int64, in nome: String) throws {
        let pulito = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pulito.isEmpty else { throw ErroreRitorno.nomeVuoto }
        try cambia { try esegui("UPDATE raccolte SET nome = ? WHERE id = ?", [pulito, numero]) }
    }

    public func aggiungi(_ impronte: [String], a numero: Int64) throws {
        try cambia {
            for i in impronte {
                try esegui("INSERT INTO raccolte_scatti (raccolta_id, impronta) VALUES (?, ?) "
                           + "ON CONFLICT(raccolta_id, impronta) DO NOTHING", [numero, i])
            }
        }
    }

    public func togli(_ impronte: [String], da numero: Int64) throws {
        try cambia {
            for i in impronte {
                try esegui("DELETE FROM raccolte_scatti WHERE raccolta_id = ? AND impronta = ?", [numero, i])
            }
        }
    }

    public func butta(_ numero: Int64) throws {
        try cambia {
            try esegui("DELETE FROM raccolte_scatti WHERE raccolta_id = ?", [numero])
            try esegui("DELETE FROM raccolte WHERE id = ?", [numero])
        }
    }

    public func apertura(_ apertoIl: String, durataS: Int64?, latitudine: Double? = nil,
                         longitudine: Double? = nil, quanteFoto: Int64? = nil) throws {
        try cambia {
            try esegui("INSERT INTO diario (aperto_il, durata_s, latitudine, longitudine, quante_foto) "
                       + "VALUES (?, ?, ?, ?, ?) ON CONFLICT(aperto_il) DO NOTHING",
                       [apertoIl, durataS as Any, latitudine as Any, longitudine as Any, quanteFoto as Any])
        }
    }

    public func byte() throws -> Data {
        var quanto: sqlite3_int64 = 0
        guard let p = sqlite3_serialize(db, "main", &quanto, 0) else { throw ErroreRitorno.nonScritto }
        defer { sqlite3_free(p) }
        return Data(bytes: p, count: Int(quanto))
    }

    private func cambia(_ fai: () throws -> Void) throws {
        let prima = try byte()
        do {
            try esegui("BEGIN")
            try fai()
            try esegui("COMMIT")
            try salva()
        } catch {
            sqlite3_close(db)
            db = nil
            try? apri(prima)
            throw error
        }
    }

    private func salva() throws {
        try esegui("INSERT INTO informazioni (chiave, valore) VALUES ('scritto_il', ?) "
                   + "ON CONFLICT(chiave) DO UPDATE SET valore = excluded.valore", [Ritorno.adesso()])
        let chiuso = try chiave.cifra(byte(), posto: Ritorno.posto)
        let fm = FileManager.default
        let provvisorio = dove.deletingLastPathComponent().appendingPathComponent(dove.lastPathComponent + ".parziale")
        do {
            try fm.createDirectory(at: dove.deletingLastPathComponent(), withIntermediateDirectories: true)
            try chiuso.write(to: provvisorio, options: [.completeFileProtection])
            guard rename(provvisorio.path, dove.path) == 0 else { throw ErroreRitorno.nonScritto }
        } catch {
            try? fm.removeItem(at: provvisorio)
            throw ErroreRitorno.nonScritto
        }
    }

    private static func mettiDaParte(_ dove: URL) throws {
        let millesimi = Int64(Date().timeIntervalSince1970 * 1000)
        let via = dove.deletingLastPathComponent()
            .appendingPathComponent(dove.lastPathComponent + ".illeggibile-\(millesimi)")
        do {
            try FileManager.default.moveItem(at: dove, to: via)
        } catch {
            throw ErroreRitorno.nonSpostato
        }
    }

    private func apri(_ dati: Data?) throws {
        guard sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_MEMORY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            db = nil
            throw ErroreVisore.archivioIlleggibile
        }
        guard let dati, !dati.isEmpty else { return }
        guard let spazio = sqlite3_malloc64(sqlite3_uint64(dati.count)) else { throw ErroreVisore.archivioIlleggibile }
        dati.copyBytes(to: spazio.assumingMemoryBound(to: UInt8.self), count: dati.count)
        let modo = UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE)
        let lungo = sqlite3_int64(dati.count)
        guard sqlite3_deserialize(db, "main", spazio.assumingMemoryBound(to: UInt8.self), lungo, lungo, modo) == SQLITE_OK,
              (try? righe("SELECT count(*) FROM sqlite_master", []) { $0.intero(0) }) != nil,
              ((try? righe("PRAGMA quick_check", []) { $0.testo(0) ?? "" })?.first ?? "") == "ok"
        else { throw ErroreVisore.archivioIlleggibile }
    }

    private func riprendi(_ scorta: Scorta) throws -> Bool {
        guard !scorta.cuori.isEmpty || !scorta.raccolte.isEmpty else { return false }
        for c in scorta.cuori {
            try esegui("INSERT INTO cuori (impronta, messo_il) VALUES (?, ?) ON CONFLICT(impronta) DO NOTHING",
                       [c.impronta, c.messoIl as Any])
        }
        for r in scorta.raccolte {
            try esegui("INSERT INTO raccolte (id, nome, creata_il) VALUES (?, ?, ?) ON CONFLICT(id) DO NOTHING",
                       [r.numero, r.nome, r.creataIl as Any])
            for i in r.impronte {
                try esegui("INSERT INTO raccolte_scatti (raccolta_id, impronta) VALUES (?, ?) "
                           + "ON CONFLICT(raccolta_id, impronta) DO NOTHING", [r.numero, i])
            }
        }
        return true
    }

    private func applica(_ tolti: [Cuore]) throws -> Bool {
        var cambiato = false
        for t in tolti {
            let messi = try righe("SELECT messo_il FROM cuori WHERE impronta = ?", [t.impronta]) { $0.testo(0) }
            guard let messo = messi.first else { continue }
            if let messo, let tolto = t.messoIl, messo > tolto { continue }
            try esegui("DELETE FROM cuori WHERE impronta = ?", [t.impronta])
            cambiato = true
        }
        return cambiato
    }

    private func esegui(_ sql: String, _ legami: [Any] = []) throws {
        _ = try righe(sql, legami) { _ in 0 }
    }

    private func righe<T>(_ sql: String, _ legami: [Any], _ fai: (Archivio.Riga) -> T) throws -> [T] {
        var s: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK, let s else {
            throw ErroreVisore.archivioIlleggibile
        }
        defer { sqlite3_finalize(s) }
        let transitorio = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (i, valore) in legami.enumerated() {
            let posto = Int32(i + 1)
            switch valore {
            case let v as Int64: sqlite3_bind_int64(s, posto, v)
            case let v as Double: sqlite3_bind_double(s, posto, v)
            case let v as String: sqlite3_bind_text(s, posto, v, -1, transitorio)
            default: sqlite3_bind_null(s, posto)
            }
        }
        var uscita: [T] = []
        while true {
            let passo = sqlite3_step(s)
            if passo == SQLITE_DONE { break }
            guard passo == SQLITE_ROW else { throw ErroreVisore.archivioIlleggibile }
            uscita.append(fai(Archivio.Riga(s: s)))
        }
        return uscita
    }
}
