import Foundation
import SQLite3

public struct Scatto: Identifiable, Hashable {
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

public struct Nodo: Identifiable, Hashable {
    public let id: Int64
    public let genitoreId: Int64?
    public let nome: String
    public let quanti: Int
    public let quantiColRamo: Int
}

public struct Persona: Identifiable, Hashable {
    public let id: Int64
    public let nome: String
    public let volto: String?
    public let quanti: Int
    public let dal: String?
    public let al: String?
}

public struct Compagno: Identifiable, Hashable {
    public var id: Int64 { persona.id }
    public let persona: Persona
    public let quante: Int
}

public struct Luogo: Identifiable, Hashable {
    public let id: Int64
    public let nome: String
    public let quanti: Int
}

public struct Anno: Identifiable, Hashable {
    public var id: String { anno }
    public let anno: String
    public let quanti: Int
}

public struct Dettagli: Equatable {
    public let nodi: [Nodo]
    public let persone: [Persona]
}

public struct Trovati: Equatable {
    public let persone: [Persona]
    public let nodi: [Nodo]
    public let luoghi: [Luogo]
    public let anni: [Anno]

    public var vuoto: Bool { persone.isEmpty && nodi.isEmpty && luoghi.isEmpty && anni.isEmpty }
}

public struct Filtro: Hashable {
    public var parole: [String]
    public var persone: [Int64]
    public var nodo: Int64?
    public var soloQui: Bool
    public var luogo: Int64?
    public var anno: String?
    public var genere: String?
    public var vecchiePrima: Bool

    public init(parole: [String] = [], persone: [Int64] = [], nodo: Int64? = nil, soloQui: Bool = false,
                luogo: Int64? = nil, anno: String? = nil, genere: String? = nil, vecchiePrima: Bool = false) {
        self.parole = parole
        self.persone = persone
        self.nodo = nodo
        self.soloQui = soloQui
        self.luogo = luogo
        self.anno = anno
        self.genere = genere
        self.vecchiePrima = vecchiePrima
    }

    public static func parole(di testo: String) -> [String] {
        var viste = Set<String>()
        return testo.lowercased().split(whereSeparator: \.isWhitespace).map(String.init).filter { viste.insert($0).inserted }
    }

    public var vuoto: Bool {
        parole.isEmpty && persone.isEmpty && nodo == nil && luogo == nil && anno == nil && genere == nil
    }
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
        try scatti(filtro: Filtro(persone: persona.map { [$0] } ?? [], nodo: nodo, soloQui: soloQui),
                   limite: limite, dopo: dopo)
    }

    public func scatti(filtro: Filtro, limite: Int = 500, dopo: Int = 0) throws -> [Scatto] {
        let (dove, legami) = Archivio.condizioni(filtro)
        let sql = "SELECT \(campiScatto) \(daScatti) \(dove) ORDER BY \(Archivio.ordine(filtro)) LIMIT ? OFFSET ?"
        return try righe(sql, legami + [Int64(limite), Int64(dopo)]) { r in
            Archivio.scatto(r)
        }
    }

    public func quanti(filtro: Filtro = Filtro()) throws -> Int {
        let (dove, legami) = Archivio.condizioni(filtro)
        return try righe("SELECT count(*) FROM scatti s \(dove)", legami) { Int($0.intero(0) ?? 0) }.first ?? 0
    }

    static func ordine(_ f: Filtro) -> String {
        f.vecchiePrima ? "s.giorno IS NULL, s.giorno ASC, s.istante_utc ASC, s.id"
                       : "s.giorno IS NULL, s.giorno DESC, s.istante_utc DESC, s.id"
    }

    static func simile(_ testo: String) -> String {
        testo.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
    }

    static func annoScritto(_ parola: String) -> Bool {
        parola.count == 4 && parola.allSatisfy { $0.isASCII && $0.isNumber }
    }

    static func condizioni(_ f: Filtro) -> (String, [Any]) {
        var parti: [String] = []
        var legami: [Any] = []
        if let nodo = f.nodo {
            if f.soloQui {
                parti.append("s.id IN (SELECT scatto_id FROM etichette WHERE nodo_id = ?)")
            } else {
                parti.append("""
                s.id IN (SELECT scatto_id FROM etichette WHERE nodo_id IN (
                  WITH RECURSIVE ramo(id) AS (SELECT ? UNION SELECT n.id FROM nodi n JOIN ramo r ON n.genitore_id = r.id)
                  SELECT id FROM ramo))
                """)
            }
            legami.append(nodo)
        }
        for p in f.persone {
            parti.append("s.id IN (SELECT scatto_id FROM persone_negli_scatti WHERE persona_id = ?)")
            legami.append(p)
        }
        if let l = f.luogo {
            parti.append("s.luogo_id = ?")
            legami.append(l)
        }
        if let a = f.anno {
            parti.append("s.giorno LIKE ?")
            legami.append(a + "-%")
        }
        if let g = f.genere {
            parti.append("s.genere = ?")
            legami.append(g)
        }
        for p in f.parole {
            let dentro = "%" + simile(p) + "%"
            var una = "s.id IN (SELECT scatto_id FROM parole WHERE parola = ?) OR s.nota LIKE ? ESCAPE '\\' "
                + "OR s.id IN (SELECT e.scatto_id FROM etichette e JOIN nodi n ON n.id = e.nodo_id WHERE n.nome LIKE ? ESCAPE '\\')"
            legami += [p, dentro, dentro]
            if annoScritto(p) {
                una += " OR s.giorno LIKE ?"
                legami.append(p + "-%")
            }
            parti.append("(" + una + ")")
        }
        return (parti.isEmpty ? "" : "WHERE " + parti.joined(separator: " AND "), legami)
    }

    static func scatto(_ r: Riga) -> Scatto {
        Scatto(id: r.intero(0)!, genere: r.testo(1)!, giorno: r.testo(2), posto: r.testo(3)!,
               postoMovimento: r.testo(4), mini: r.testo(5), larghezza: r.intero(6).map(Int.init),
               altezza: r.intero(7).map(Int.init), durataMs: r.intero(8).map(Int.init), nota: r.testo(9),
               dataLocale: r.testo(10), luogo: r.testo(11))
    }

    public func giorni(filtro: Filtro = Filtro()) throws -> [Giorno] {
        let (dove, legami) = Archivio.condizioni(filtro)
        let verso = filtro.vecchiePrima ? "ASC" : "DESC"
        let sql = """
        SELECT s.giorno, count(*), group_concat(l.nome, char(31))
        FROM scatti s LEFT JOIN luoghi l ON l.id = s.luogo_id \(dove)
        GROUP BY s.giorno ORDER BY s.giorno IS NULL, s.giorno \(verso)
        """
        return try righe(sql, legami) { r in
            var visti: [String: Int] = [:]
            for nome in (r.testo(2) ?? "").split(separator: "\u{1F}").map(String.init) where !nome.isEmpty {
                visti[nome, default: 0] += 1
            }
            let luoghi = visti.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
            return Giorno(giorno: r.testo(0), quanti: Int(r.intero(1)!), luoghi: luoghi)
        }
    }

    private let campiNodo = "id, genitore_id, nome, quanti, quanti_col_ramo"
    private let campiPersona = "p.id, p.nome, p.volto, p.quanti, p.dal_giorno, p.al_giorno"

    static func nodo(_ r: Riga) -> Nodo {
        Nodo(id: r.intero(0)!, genitoreId: r.intero(1), nome: r.testo(2)!,
             quanti: Int(r.intero(3)!), quantiColRamo: Int(r.intero(4)!))
    }

    static func persona(_ r: Riga) -> Persona {
        Persona(id: r.intero(0)!, nome: r.testo(1)!, volto: r.testo(2), quanti: Int(r.intero(3)!),
                dal: r.testo(4), al: r.testo(5))
    }

    public func nodi(figliDi genitore: Int64?) throws -> [Nodo] {
        let sql = genitore == nil
            ? "SELECT \(campiNodo) FROM nodi WHERE genitore_id IS NULL AND quanti_col_ramo > 0 ORDER BY posizione, id"
            : "SELECT \(campiNodo) FROM nodi WHERE genitore_id = ? AND quanti_col_ramo > 0 ORDER BY posizione, id"
        return try righe(sql, genitore.map { [$0] } ?? [], Archivio.nodo)
    }

    public func nodo(_ id: Int64) throws -> Nodo? {
        try righe("SELECT \(campiNodo) FROM nodi WHERE id = ?", [id], Archivio.nodo).first
    }

    public func copertina(nodo: Int64) throws -> Scatto? {
        try scatti(filtro: Filtro(nodo: nodo), limite: 1).first
    }

    public func persone() throws -> [Persona] {
        try righe("SELECT \(campiPersona) FROM persone p WHERE p.quanti > 0 ORDER BY p.quanti DESC, p.nome, p.id", [],
                  Archivio.persona)
    }

    public func persona(_ id: Int64) throws -> Persona? {
        try righe("SELECT \(campiPersona) FROM persone p WHERE p.id = ?", [id], Archivio.persona).first
    }

    public func insieme(a persona: Int64) throws -> [Compagno] {
        let sql = """
        SELECT \(campiPersona), i.quante FROM insieme i JOIN persone p ON p.id = i.altra_id
        WHERE i.persona_id = ? AND i.altra_id <> i.persona_id AND i.quante > 0 ORDER BY i.quante DESC, p.nome, p.id
        """
        return try righe(sql, [persona]) { r in
            Compagno(persona: Archivio.persona(r), quante: Int(r.intero(6) ?? 0))
        }
    }

    public func luoghi() throws -> [Luogo] {
        let sql = """
        SELECT l.id, l.nome, count(s.id) AS n FROM luoghi l JOIN scatti s ON s.luogo_id = l.id
        WHERE l.nome IS NOT NULL AND l.nome <> '' GROUP BY l.id ORDER BY n DESC, l.nome
        """
        return try righe(sql, []) { r in Luogo(id: r.intero(0)!, nome: r.testo(1)!, quanti: Int(r.intero(2)!)) }
    }

    public func anni() throws -> [Anno] {
        let sql = """
        SELECT substr(giorno, 1, 4) AS a, count(*) FROM scatti WHERE giorno IS NOT NULL
        GROUP BY a ORDER BY a DESC
        """
        return try righe(sql, []) { r in Anno(anno: r.testo(0)!, quanti: Int(r.intero(1)!)) }
    }

    public func dettagli(_ scatto: Int64) throws -> Dettagli {
        let nodi = try righe("""
            SELECT n.id, n.genitore_id, n.nome, n.quanti, n.quanti_col_ramo FROM etichette e
            JOIN nodi n ON n.id = e.nodo_id WHERE e.scatto_id = ? ORDER BY n.posizione, n.id
            """, [scatto], Archivio.nodo)
        let persone = try righe("""
            SELECT \(campiPersona) FROM persone_negli_scatti x JOIN persone p ON p.id = x.persona_id
            WHERE x.scatto_id = ? ORDER BY p.quanti DESC, p.nome, p.id
            """, [scatto], Archivio.persona)
        return Dettagli(nodi: nodi, persone: persone)
    }

    public func trovati(_ testo: String) throws -> Trovati {
        let scritto = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !scritto.isEmpty else { return Trovati(persone: [], nodi: [], luoghi: [], anni: []) }
        let inizio = Archivio.simile(scritto) + "%"
        let parola = "% " + inizio
        let persone = try righe("""
            SELECT \(campiPersona) FROM persone p WHERE p.quanti > 0
            AND (p.nome LIKE ? ESCAPE '\\' OR p.nome LIKE ? ESCAPE '\\') ORDER BY p.quanti DESC, p.nome LIMIT 20
            """, [inizio, parola], Archivio.persona)
        let nodi = try righe("""
            SELECT \(campiNodo) FROM nodi WHERE quanti_col_ramo > 0
            AND (nome LIKE ? ESCAPE '\\' OR nome LIKE ? ESCAPE '\\') ORDER BY quanti_col_ramo DESC, nome LIMIT 20
            """, [inizio, parola], Archivio.nodo)
        let luoghi = try righe("""
            SELECT l.id, l.nome, count(s.id) AS n FROM luoghi l JOIN scatti s ON s.luogo_id = l.id
            WHERE l.nome LIKE ? ESCAPE '\\' OR l.nome LIKE ? ESCAPE '\\' GROUP BY l.id ORDER BY n DESC, l.nome LIMIT 20
            """, [inizio, parola]) { r in Luogo(id: r.intero(0)!, nome: r.testo(1)!, quanti: Int(r.intero(2)!)) }
        var anni: [Anno] = []
        if Archivio.annoScritto(scritto) {
            let n = try quanti(filtro: Filtro(anno: scritto))
            if n > 0 { anni = [Anno(anno: scritto, quanti: n)] }
        }
        return Trovati(persone: persone, nodi: nodi, luoghi: luoghi, anni: anni)
    }

    public func ciSonoParole() -> Bool {
        ((try? righe("SELECT EXISTS (SELECT 1 FROM parole)", []) { $0.intero(0) ?? 0 })?.first ?? 0) == 1
    }

    public func informazioni() -> [String: String] {
        let coppie = (try? righe("SELECT chiave, valore FROM informazioni", []) { ($0.testo(0) ?? "", $0.testo(1) ?? "") }) ?? []
        return Dictionary(coppie, uniquingKeysWith: { a, _ in a })
    }

    public func cerca(_ testo: String, limite: Int = 200) throws -> [Scatto] {
        let parole = Filtro.parole(di: testo)
        guard !parole.isEmpty else { return [] }
        return try scatti(filtro: Filtro(parole: parole), limite: limite)
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
