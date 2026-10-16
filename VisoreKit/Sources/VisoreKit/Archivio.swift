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
    private let campiScatto = "id, genere, giorno, posto, posto_movimento, mini, larghezza, altezza, durata_ms, nota"

    public init(percorso: URL) throws {
        guard sqlite3_open_v2(percorso.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
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
                dove = "WHERE id IN (SELECT scatto_id FROM etichette WHERE nodo_id = ?)"
            } else {
                dove = """
                WHERE id IN (SELECT scatto_id FROM etichette WHERE nodo_id IN (
                  WITH RECURSIVE ramo(id) AS (SELECT ? UNION SELECT n.id FROM nodi n JOIN ramo r ON n.genitore_id = r.id)
                  SELECT id FROM ramo))
                """
            }
            legami.append(nodo)
        }
        if let persona {
            dove += (dove.isEmpty ? "WHERE " : " AND ") + "id IN (SELECT scatto_id FROM persone_negli_scatti WHERE persona_id = ?)"
            legami.append(persona)
        }
        let sql = "SELECT \(campiScatto) FROM scatti \(dove) ORDER BY giorno IS NULL, giorno DESC, istante_utc DESC LIMIT ? OFFSET ?"
        return try righe(sql, legami + [Int64(limite), Int64(dopo)]) { r in
            Scatto(id: r.intero(0)!, genere: r.testo(1)!, giorno: r.testo(2), posto: r.testo(3)!,
                   postoMovimento: r.testo(4), mini: r.testo(5), larghezza: r.intero(6).map(Int.init),
                   altezza: r.intero(7).map(Int.init), durataMs: r.intero(8).map(Int.init), nota: r.testo(9))
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
            "(id IN (SELECT scatto_id FROM parole WHERE parola = ?) OR nota LIKE ? ESCAPE '\\' "
            + "OR id IN (SELECT e.scatto_id FROM etichette e JOIN nodi n ON n.id = e.nodo_id WHERE n.nome LIKE ? ESCAPE '\\'))"
        }.joined(separator: " AND ")
        var legami: [Any] = []
        for p in parole {
            let simile = "%" + p.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_") + "%"
            legami += [p, simile, simile]
        }
        let sql = "SELECT \(campiScatto) FROM scatti WHERE \(condizioni) ORDER BY giorno IS NULL, giorno DESC LIMIT ?"
        return try righe(sql, legami + [Int64(limite)]) { r in
            Scatto(id: r.intero(0)!, genere: r.testo(1)!, giorno: r.testo(2), posto: r.testo(3)!,
                   postoMovimento: r.testo(4), mini: r.testo(5), larghezza: r.intero(6).map(Int.init),
                   altezza: r.intero(7).map(Int.init), durataMs: r.intero(8).map(Int.init), nota: r.testo(9))
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
