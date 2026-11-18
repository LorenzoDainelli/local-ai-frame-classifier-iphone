import Foundation
import SQLite3

public struct Scatto: Identifiable, Equatable {
    public let id: Int64
    public let genere: String
    public let giorno: String?
    public let posto: String
    public let postoMovimento: String?
    public let mini: String?
    public let larghezza: Int?
    public let altezza: Int?
    public let durataMs: Int?
    public let nota: String?
    public let dataLocale: String?
    public let luogo: String?

    public var live: Bool { genere == "live" && postoMovimento != nil }
    public var video: Bool { genere == "video" }
}

public struct Giorno: Identifiable, Equatable {
    public var id: String { giorno ?? "" }
    public let giorno: String?
    public let quanti: Int
    public let luoghi: [String]
}

public struct Nodo: Identifiable, Equatable {
    public let id: Int64
    public let genitoreId: Int64?
    public let nome: String
    public let quanti: Int
    public let quantiColRamo: Int
}

public struct Persona: Identifiable, Equatable {
    public let id: Int64
    public let nome: String
    public let volto: String?
    public let quanti: Int
}

public final class Archivio {

    private var db: OpaquePointer?
    private let campiScatto = "s.id, s.genere, s.giorno, s.posto, s.posto_movimento, s.mini, s.larghezza, s.altezza, s.durata_ms, s.nota, s.data_locale, l.nome"
    private let daScatti = "FROM scatti s LEFT JOIN luoghi l ON l.id = s.luogo_id"

    public init(percorso: URL) throws {
        guard sqlite3_open_v2(percorso.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            db = nil
            throw ErroreVisore.archivioIlleggibile
        }
    }

    public init(dati: Data) throws {
        guard !dati.isEmpty,
              sqlite3_open_v2(":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_MEMORY, nil) == SQLITE_OK,
              let spazio = sqlite3_malloc64(sqlite3_uint64(dati.count)) else {
            sqlite3_close(db)
            db = nil
            throw ErroreVisore.archivioIlleggibile
        }
        dati.copyBytes(to: spazio.assumingMemoryBound(to: UInt8.self), count: dati.count)
        let modo = UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_READONLY)
        let lungo = sqlite3_int64(dati.count)
        guard sqlite3_deserialize(db, "main", spazio.assumingMemoryBound(to: UInt8.self), lungo, lungo, modo) == SQLITE_OK,
              (try? righe("SELECT count(*) FROM sqlite_master", []) { $0.intero(0) }) != nil else {
            sqlite3_close(db)
            db = nil
            throw ErroreVisore.archivioIlleggibile
        }
    }

    deinit { sqlite3_close(db) }

    public func scatti(nodo: Int64? = nil, persona: Int64? = nil, soloQui: Bool = false,
                       limite: Int = 500, dopo: Int = 0) throws -> [Scatto] {
        var dove = ""
        var legami: [Int64] = []
        if let nodo {
            if soloQui {
                dove = "WHERE s.id IN (SELECT scatto_id FROM etichette WHERE nodo_id = ?)"
            } else {
                dove = """
                WHERE s.id IN (SELECT scatto_id FROM etichette WHERE nodo_id IN (
                  WITH RECURSIVE ramo(id) AS (SELECT ? UNION SELECT n.id FROM nodi n JOIN ramo r ON n.genitore_id = r.id)
                  SELECT id FROM ramo))
                """
            }
            legami.append(nodo)
        }
        if let persona {
            dove += (dove.isEmpty ? "WHERE " : " AND ") + "s.id IN (SELECT scatto_id FROM persone_negli_scatti WHERE persona_id = ?)"
            legami.append(persona)
        }
        let sql = "SELECT \(campiScatto) \(daScatti) \(dove) ORDER BY s.giorno IS NULL, s.giorno DESC, s.istante_utc DESC, s.id LIMIT ? OFFSET ?"
        return try righe(sql, legami + [Int64(limite), Int64(dopo)]) { r in
            Archivio.scatto(r)
        }
    }

    static func scatto(_ r: Riga) -> Scatto {
        Scatto(id: r.intero(0)!, genere: r.testo(1)!, giorno: r.testo(2), posto: r.testo(3)!,
               postoMovimento: r.testo(4), mini: r.testo(5), larghezza: r.intero(6).map(Int.init),
               altezza: r.intero(7).map(Int.init), durataMs: r.intero(8).map(Int.init), nota: r.testo(9),
               dataLocale: r.testo(10), luogo: r.testo(11))
    }

    public func giorni() throws -> [Giorno] {
        let sql = """
        SELECT s.giorno, count(*), group_concat(l.nome, char(31))
        FROM scatti s LEFT JOIN luoghi l ON l.id = s.luogo_id
        GROUP BY s.giorno ORDER BY s.giorno IS NULL, s.giorno DESC
        """
        return try righe(sql, []) { r in
            var visti: [String: Int] = [:]
            for nome in (r.testo(2) ?? "").split(separator: "\u{1F}").map(String.init) where !nome.isEmpty {
                visti[nome, default: 0] += 1
            }
            let luoghi = visti.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
            return Giorno(giorno: r.testo(0), quanti: Int(r.intero(1)!), luoghi: luoghi)
        }
    }

    public func nodi(figliDi genitore: Int64?) throws -> [Nodo] {
        let sql = genitore == nil
            ? "SELECT id, genitore_id, nome, quanti, quanti_col_ramo FROM nodi WHERE genitore_id IS NULL ORDER BY posizione, id"
            : "SELECT id, genitore_id, nome, quanti, quanti_col_ramo FROM nodi WHERE genitore_id = ? ORDER BY posizione, id"
        return try righe(sql, genitore.map { [$0] } ?? []) { r in
            Nodo(id: r.intero(0)!, genitoreId: r.intero(1), nome: r.testo(2)!,
                 quanti: Int(r.intero(3)!), quantiColRamo: Int(r.intero(4)!))
        }
    }

    public func persone() throws -> [Persona] {
        try righe("SELECT id, nome, volto, quanti FROM persone ORDER BY quanti DESC, nome", []) { r in
            Persona(id: r.intero(0)!, nome: r.testo(1)!, volto: r.testo(2), quanti: Int(r.intero(3)!))
        }
    }

    public func cerca(_ testo: String, limite: Int = 200) throws -> [Scatto] {
        let parole = testo.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !parole.isEmpty else { return [] }
        let condizioni = parole.map { _ in
            "(s.id IN (SELECT scatto_id FROM parole WHERE parola = ?) OR s.nota LIKE ? ESCAPE '\\' "
            + "OR s.id IN (SELECT e.scatto_id FROM etichette e JOIN nodi n ON n.id = e.nodo_id WHERE n.nome LIKE ? ESCAPE '\\'))"
        }.joined(separator: " AND ")
        var legami: [Any] = []
        for p in parole {
            let simile = "%" + p.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_") + "%"
            legami += [p, simile, simile]
        }
        let sql = "SELECT \(campiScatto) \(daScatti) WHERE \(condizioni) ORDER BY s.giorno IS NULL, s.giorno DESC, s.istante_utc DESC, s.id LIMIT ?"
        return try righe(sql, legami + [Int64(limite)]) { r in
            Archivio.scatto(r)
        }
    }

    struct Riga {
        let s: OpaquePointer
        func intero(_ i: Int32) -> Int64? {
            sqlite3_column_type(s, i) == SQLITE_NULL ? nil : sqlite3_column_int64(s, i)
        }
        func testo(_ i: Int32) -> String? {
            guard let c = sqlite3_column_text(s, i) else { return nil }
            return String(cString: c)
        }
    }

    private func righe<T>(_ sql: String, _ legami: [Any], _ fai: (Riga) -> T) throws -> [T] {
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
            case let v as String: sqlite3_bind_text(s, posto, v, -1, transitorio)
            default: throw ErroreVisore.archivioIlleggibile
            }
        }
        var uscita: [T] = []
        while true {
            let passo = sqlite3_step(s)
            if passo == SQLITE_DONE { break }
            guard passo == SQLITE_ROW else { throw ErroreVisore.archivioIlleggibile }
            uscita.append(fai(Riga(s: s)))
        }
        return uscita
    }
}
