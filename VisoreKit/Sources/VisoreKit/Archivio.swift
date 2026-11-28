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
    public let impronta: String

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

public struct NodoContato: Identifiable, Hashable {
    public var id: Int64 { nodo.id }
    public let nodo: Nodo
    public let quante: Int
}

public struct Riassunto: Equatable {
    public let quanti: Int
    public let video: Int
    public let dal: String?
    public let al: String?
    public let anni: [Anno]
    public let luoghi: [Luogo]
    public let persone: [Compagno]
    public let nodi: [NodoContato]
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
    public var impronte: [String]?

    public init(parole: [String] = [], persone: [Int64] = [], nodo: Int64? = nil, soloQui: Bool = false,
                luogo: Int64? = nil, anno: String? = nil, genere: String? = nil, vecchiePrima: Bool = false,
                impronte: [String]? = nil) {
        self.impronte = impronte
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
            && impronte == nil
    }
}

public final class Archivio {

    private var db: OpaquePointer?
    private let campiScatto = "s.id, s.genere, s.giorno, s.posto, s.posto_movimento, s.mini, s.larghezza, s.altezza, s.durata_ms, s.nota, s.data_locale, l.nome, s.impronta"
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
        if let i = f.impronte {
            let elenco = (try? JSONSerialization.data(withJSONObject: i)).flatMap { String(data: $0, encoding: .utf8) }
            parti.append("s.impronta IN (SELECT value FROM json_each(?))")
            legami.append(elenco ?? "[]")
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
               dataLocale: r.testo(10), luogo: r.testo(11), impronta: r.testo(12) ?? "")
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

    public func nodi(con ids: [Int64]) throws -> [Nodo] {
        guard !ids.isEmpty else { return [] }
        let posti = Array(repeating: "?", count: ids.count).joined(separator: ",")
        let trovati = try righe("SELECT \(campiNodo) FROM nodi WHERE id IN (\(posti)) AND quanti_col_ramo > 0",
                                ids, Archivio.nodo)
        let perId = Dictionary(trovati.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return ids.compactMap { perId[$0] }
    }

    public func nodo(_ id: Int64) throws -> Nodo? {
        try righe("SELECT \(campiNodo) FROM nodi WHERE id = ?", [id], Archivio.nodo).first
    }

    public func copertina(nodo: Int64) throws -> Scatto? {
        try scatti(filtro: Filtro(nodo: nodo), limite: 1).first
    }

    static func anche(_ dove: String, _ altro: String) -> String {
        dove.isEmpty ? "WHERE " + altro : dove + " AND " + altro
    }

    public func copertine(filtro: Filtro, quante: Int = 4) throws -> [Scatto] {
        let tutti = try scatti(filtro: filtro, limite: 400)
        var giorni = Set<String>()
        var scelti: [Scatto] = []
        for s in tutti where scelti.count < quante && giorni.insert(s.giorno ?? "").inserted {
            scelti.append(s)
        }
        for s in tutti where scelti.count < quante && !scelti.contains(s) {
            scelti.append(s)
        }
        return scelti
    }

    public func anni(filtro: Filtro) throws -> [Anno] {
        let (dove, legami) = Archivio.condizioni(filtro)
        let sql = """
        SELECT substr(s.giorno, 1, 4) AS a, count(*) FROM scatti s \(Archivio.anche(dove, "s.giorno IS NOT NULL"))
        GROUP BY a ORDER BY a DESC
        """
        return try righe(sql, legami) { r in Anno(anno: r.testo(0)!, quanti: Int(r.intero(1)!)) }
    }

    public func luoghi(filtro: Filtro, limite: Int = 10) throws -> [Luogo] {
        let (dove, legami) = Archivio.condizioni(filtro)
        let sql = """
        SELECT l.id, l.nome, count(*) AS n FROM scatti s JOIN luoghi l ON l.id = s.luogo_id
        \(Archivio.anche(dove, "l.nome IS NOT NULL AND l.nome <> ''"))
        GROUP BY l.id ORDER BY n DESC, l.nome, l.id LIMIT ?
        """
        return try righe(sql, legami + [Int64(limite)]) { r in
            Luogo(id: r.intero(0)!, nome: r.testo(1)!, quanti: Int(r.intero(2)!))
        }
    }

    public func persone(filtro: Filtro, limite: Int = 10) throws -> [Compagno] {
        let (dove, legami) = Archivio.condizioni(filtro)
        let tranne = "[" + filtro.persone.map(String.init).joined(separator: ",") + "]"
        let sql = """
        SELECT \(campiPersona), count(*) AS n FROM scatti s
        JOIN persone_negli_scatti x ON x.scatto_id = s.id JOIN persone p ON p.id = x.persona_id
        \(Archivio.anche(dove, "p.id NOT IN (SELECT value FROM json_each(?))"))
        GROUP BY p.id ORDER BY n DESC, p.nome, p.id LIMIT ?
        """
        return try righe(sql, legami + [tranne as Any, Int64(limite)]) { r in
            Compagno(persona: Archivio.persona(r), quante: Int(r.intero(6) ?? 0))
        }
    }

    public func nodi(filtro: Filtro, figliDi genitore: Int64? = nil, limite: Int = 10) throws -> [NodoContato] {
        let (dove, legami) = Archivio.condizioni(filtro)
        let teste = genitore == nil
            ? "SELECT id, id FROM nodi WHERE genitore_id IS NULL"
            : "SELECT id, id FROM nodi WHERE genitore_id = ?"
        let sql = """
        WITH RECURSIVE capo(id, testa) AS (\(teste)
          UNION ALL SELECT n.id, c.testa FROM nodi n JOIN capo c ON n.genitore_id = c.id)
        SELECT n.id, n.genitore_id, n.nome, n.quanti, n.quanti_col_ramo, count(DISTINCT s.id) AS q
        FROM scatti s JOIN etichette e ON e.scatto_id = s.id JOIN capo c ON c.id = e.nodo_id
        JOIN nodi n ON n.id = c.testa \(dove)
        GROUP BY n.id ORDER BY q DESC, n.posizione, n.id LIMIT ?
        """
        let prima: [Any] = genitore.map { [$0] } ?? []
        return try righe(sql, prima + legami + [Int64(limite)]) { r in
            NodoContato(nodo: Archivio.nodo(r), quante: Int(r.intero(5) ?? 0))
        }
    }

    public func riassunto(filtro: Filtro, figliDi genitore: Int64? = nil) throws -> Riassunto {
        let (dove, legami) = Archivio.condizioni(filtro)
        let sql = """
        SELECT count(*), coalesce(sum(s.genere = 'video'), 0), min(s.giorno), max(s.giorno) FROM scatti s \(dove)
        """
        let conti = try righe(sql, legami) { r in
            (Int(r.intero(0) ?? 0), Int(r.intero(1) ?? 0), r.testo(2), r.testo(3))
        }.first ?? (0, 0, nil, nil)
        return Riassunto(quanti: conti.0, video: conti.1, dal: conti.2, al: conti.3,
                         anni: try anni(filtro: filtro), luoghi: try luoghi(filtro: filtro),
                         persone: try persone(filtro: filtro),
                         nodi: try nodi(filtro: filtro, figliDi: genitore))
    }

    public func personePerNome() throws -> [Persona] {
        try persone().sorted {
            let ordine = $0.nome.localizedCaseInsensitiveCompare($1.nome)
            return ordine == .orderedSame ? $0.id < $1.id : ordine == .orderedAscending
        }
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

    public func scorta() -> Scorta {
        let cuori = (try? righe("SELECT impronta, messo_il FROM cuori ORDER BY impronta", []) {
            Cuore(impronta: $0.testo(0) ?? "", messoIl: $0.testo(1))
        }) ?? []
        let tolti = (try? righe("SELECT impronta, tolto_il FROM cuori_tolti ORDER BY impronta", []) {
            Cuore(impronta: $0.testo(0) ?? "", messoIl: $0.testo(1))
        }) ?? []
        let teste = (try? righe("SELECT id, nome, creata_il FROM raccolte ORDER BY id", []) {
            ($0.intero(0) ?? 0, $0.testo(1) ?? "", $0.testo(2))
        }) ?? []
        let raccolte = teste.map { t in
            Raccolta(numero: t.0, nome: t.1, creataIl: t.2,
                     impronte: (try? righe("SELECT impronta FROM raccolte_scatti WHERE raccolta_id = ? ORDER BY impronta",
                                           [t.0]) { $0.testo(0) ?? "" }) ?? [])
        }
        return Scorta(cuori: cuori, tolti: tolti, raccolte: raccolte)
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

public struct Mescola: Hashable {
    public static let generiTutti = ["foto", "live", "video"]

    public var generi: Set<String>
    public var nodi: Set<Int64>
    public var persone: Set<Int64>
    public var anni: Set<String>

    public init(generi: Set<String> = Set(Mescola.generiTutti), nodi: Set<Int64> = [], persone: Set<Int64> = [],
                anni: Set<String> = []) {
        self.generi = generi
        self.nodi = nodi
        self.persone = persone
        self.anni = anni
    }

    public var tutto: Bool {
        generi.count == Mescola.generiTutti.count && nodi.isEmpty && persone.isEmpty && anni.isEmpty
    }

    public static func rimescola<T>(_ elenco: [T], seme: UInt64) -> [T] {
        var uscita = elenco
        var stato = seme
        func prossimo() -> UInt64 {
            stato &+= 0x9E37_79B9_7F4A_7C15
            var z = stato
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        guard uscita.count > 1 else { return uscita }
        for i in stride(from: uscita.count - 1, to: 0, by: -1) {
            let j = Int(prossimo() % UInt64(i + 1))
            uscita.swapAt(i, j)
        }
        return uscita
    }
}

public struct Pescato: Hashable {
    public let id: Int64
    public let impronta: String
}

extension Archivio {

    static func elenco(_ valori: [Any]) -> String {
        (try? JSONSerialization.data(withJSONObject: valori)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    static func condizioni(_ m: Mescola, conGeneri: Bool = true) -> (String, [Any]) {
        var parti: [String] = []
        var legami: [Any] = []
        if conGeneri, m.generi.count < Mescola.generiTutti.count {
            parti.append("s.genere IN (SELECT value FROM json_each(?))")
            legami.append(elenco(m.generi.sorted()))
        }
        if !m.nodi.isEmpty {
            parti.append("""
            s.id IN (SELECT scatto_id FROM etichette WHERE nodo_id IN (
              WITH RECURSIVE ramo(id) AS (SELECT value FROM json_each(?) UNION SELECT n.id FROM nodi n JOIN ramo r ON n.genitore_id = r.id)
              SELECT id FROM ramo))
            """)
            legami.append(elenco(m.nodi.sorted().map { NSNumber(value: $0) }))
        }
        if !m.persone.isEmpty {
            parti.append("s.id IN (SELECT scatto_id FROM persone_negli_scatti WHERE persona_id IN (SELECT value FROM json_each(?)))")
            legami.append(elenco(m.persone.sorted().map { NSNumber(value: $0) }))
        }
        if !m.anni.isEmpty {
            parti.append("substr(s.giorno, 1, 4) IN (SELECT value FROM json_each(?))")
            legami.append(elenco(m.anni.sorted()))
        }
        return (parti.isEmpty ? "" : "WHERE " + parti.joined(separator: " AND "), legami)
    }

    public func quanti(mescola: Mescola) throws -> Int {
        let (dove, legami) = Archivio.condizioni(mescola)
        return try righe("SELECT count(*) FROM scatti s \(dove)", legami) { Int($0.intero(0) ?? 0) }.first ?? 0
    }

    public func quantiPerGenere(mescola: Mescola) throws -> [String: Int] {
        let (dove, legami) = Archivio.condizioni(mescola, conGeneri: false)
        var conti: [String: Int] = [:]
        for g in Mescola.generiTutti { conti[g] = 0 }
        let sql = "SELECT s.genere, count(*) FROM scatti s \(dove) GROUP BY s.genere"
        for (g, n) in try righe(sql, legami, { ($0.testo(0) ?? "", Int($0.intero(1) ?? 0)) }) {
            conti[g] = n
        }
        return conti
    }

    public func pescati(mescola: Mescola) throws -> [Pescato] {
        let (dove, legami) = Archivio.condizioni(mescola)
        return try righe("SELECT s.id, s.impronta FROM scatti s \(dove) ORDER BY s.id", legami) { r in
            Pescato(id: r.intero(0)!, impronta: r.testo(1) ?? "")
        }
    }

    public func scatti(numeri: [Int64]) throws -> [Scatto] {
        guard !numeri.isEmpty else { return [] }
        let sql = "SELECT \(campiScatto) \(daScatti) WHERE s.id IN (SELECT value FROM json_each(?))"
        let trovati = try righe(sql, [Archivio.elenco(numeri.map { NSNumber(value: $0) })], Archivio.scatto)
        let perNumero = Dictionary(trovati.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return numeri.compactMap { perNumero[$0] }
    }
}
