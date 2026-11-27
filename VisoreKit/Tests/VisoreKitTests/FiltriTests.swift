import Foundation
import SQLite3
import XCTest
@testable import VisoreKit

final class FiltriTests: XCTestCase {

    var archivio: Archivio!

    override func setUpWithError() throws {
        let dove = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        defer { try? FileManager.default.removeItem(at: dove) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dove.path, &db), SQLITE_OK)
        let sql = """
        CREATE TABLE informazioni (chiave TEXT PRIMARY KEY, valore TEXT NOT NULL);
        CREATE TABLE scatti (id INTEGER PRIMARY KEY, impronta TEXT NOT NULL UNIQUE, genere TEXT NOT NULL,
          giorno TEXT, data_locale TEXT, istante_utc TEXT, origine_data TEXT NOT NULL, larghezza INTEGER,
          altezza INTEGER, durata_ms INTEGER, latitudine REAL, longitudine REAL, luogo_id INTEGER, nota TEXT,
          posto TEXT NOT NULL, posto_movimento TEXT, mini TEXT, dimensione INTEGER NOT NULL);
        CREATE TABLE nodi (id INTEGER PRIMARY KEY, genitore_id INTEGER, nome TEXT NOT NULL,
          posizione INTEGER NOT NULL DEFAULT 0, quanti INTEGER NOT NULL DEFAULT 0, quanti_col_ramo INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE etichette (scatto_id INTEGER NOT NULL, nodo_id INTEGER NOT NULL, origine TEXT NOT NULL,
          PRIMARY KEY (scatto_id, nodo_id));
        CREATE TABLE persone (id INTEGER PRIMARY KEY, nome TEXT NOT NULL, volto TEXT, quanti INTEGER NOT NULL DEFAULT 0,
          dal_giorno TEXT, al_giorno TEXT);
        CREATE TABLE persone_negli_scatti (scatto_id INTEGER NOT NULL, persona_id INTEGER NOT NULL, origine TEXT NOT NULL,
          PRIMARY KEY (scatto_id, persona_id));
        CREATE TABLE insieme (persona_id INTEGER NOT NULL, altra_id INTEGER NOT NULL, quante INTEGER NOT NULL,
          PRIMARY KEY (persona_id, altra_id));
        CREATE TABLE luoghi (id INTEGER PRIMARY KEY, nome TEXT, latitudine REAL, longitudine REAL, quanti INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE parole (scatto_id INTEGER NOT NULL, parola TEXT NOT NULL, PRIMARY KEY (scatto_id, parola));
        INSERT INTO informazioni VALUES ('quanti_scatti', '8');
        INSERT INTO luoghi VALUES (1, 'Firenze', NULL, NULL, 3), (2, 'Lucca', NULL, NULL, 1), (3, NULL, NULL, NULL, 1);
        INSERT INTO scatti (id, impronta, genere, giorno, istante_utc, origine_data, luogo_id, nota, posto, dimensione) VALUES
          (1, 'a', 'foto',  '2019-05-01', '2019-05-01T08:00:00Z', 'exif', 1, 'sconto 100% vero', 'foto/1', 1),
          (2, 'b', 'live',  '2019-05-01', '2019-05-01T09:00:00Z', 'exif', 1, 'gita_a_mare', 'foto/2', 1),
          (3, 'c', 'video', '2020-07-15', '2020-07-15T10:00:00Z', 'exif', 2, NULL, 'foto/3', 1),
          (4, 'd', 'foto',  '2021-01-02', '2021-01-02T11:00:00Z', 'exif', 1, 'il 2019 era meglio', 'foto/4', 1),
          (5, 'e', 'foto',  NULL, NULL, 'dedotta', NULL, NULL, 'foto/5', 1),
          (6, 'f', 'foto',  '2021-01-02', '2021-01-02T07:00:00Z', 'exif', 3, NULL, 'foto/6', 1),
          (7, 'g', 'foto',  '2018-12-31', '2018-12-31T23:00:00Z', 'exif', NULL, NULL, 'foto/7', 1),
          (8, 'h', 'video', NULL, NULL, 'dedotta', NULL, 'gatto', 'foto/8', 1);
        INSERT INTO nodi VALUES (1, NULL, 'Animali', 0, 0, 3), (2, 1, 'Gatti', 0, 1, 2), (3, 2, 'Gatti neri', 0, 1, 1),
          (4, NULL, 'Vuoto', 1, 0, 0), (5, 1, 'Cani', 1, 0, 0), (6, NULL, 'Mare e monti', 2, 1, 1);
        INSERT INTO etichette VALUES (1, 2, 'utente'), (4, 3, 'sistema'), (3, 6, 'utente'), (6, 1, 'utente');
        INSERT INTO persone VALUES (1, 'Anna Rossi', 'volti/1', 3, '2019-05-01', '2021-01-02'),
          (2, 'Bruno', NULL, 2, '2019-05-01', '2020-07-15'), (3, 'Carla', NULL, 0, NULL, NULL), (4, 'Ossobuco', NULL, 1, NULL, NULL);
        INSERT INTO persone_negli_scatti VALUES (1, 1, 'volto'), (2, 1, 'volto'), (2, 2, 'volto'), (3, 2, 'a_mano'),
          (4, 1, 'volto'), (7, 4, 'volto');
        INSERT INTO insieme VALUES (1, 2, 1), (2, 1, 1), (1, 1, 3), (1, 4, 0);
        INSERT INTO parole VALUES (1, 'spiaggia'), (3, 'spiaggia'), (3, 'cane');
        """
        XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        archivio = try Archivio(dati: try Data(contentsOf: dove))
    }

    func ids(_ f: Filtro) throws -> [Int64] { try archivio.scatti(filtro: f).map(\.id) }

    func testSenzaFiltroLOrdineEDalPiuRecenteEISenzaDataInFondo() throws {
        XCTAssertEqual(try ids(Filtro()), [4, 6, 3, 2, 1, 7, 5, 8])
        XCTAssertEqual(try ids(Filtro(vecchiePrima: true)), [7, 1, 2, 3, 6, 4, 5, 8])
        XCTAssertEqual(try archivio.quanti(), 8)
    }

    func testDuePersoneVuolDireTutteEDue() throws {
        XCTAssertEqual(try ids(Filtro(persone: [1])), [4, 2, 1])
        XCTAssertEqual(try ids(Filtro(persone: [2])), [3, 2])
        XCTAssertEqual(try ids(Filtro(persone: [1, 2])), [2])
        XCTAssertEqual(try archivio.quanti(filtro: Filtro(persone: [1, 2])), 1)
        XCTAssertEqual(try ids(Filtro(persone: [1, 4])), [])
    }

    func testIlNodoComprendeIlRamoESoloQuiNo() throws {
        XCTAssertEqual(try ids(Filtro(nodo: 1)), [4, 6, 1])
        XCTAssertEqual(try ids(Filtro(nodo: 1, soloQui: true)), [6])
        XCTAssertEqual(try ids(Filtro(nodo: 2)), [4, 1])
        XCTAssertEqual(try ids(Filtro(nodo: 3)), [4])
        XCTAssertEqual(try ids(Filtro(nodo: 5)), [])
    }

    func testIFiltriSiSommano() throws {
        XCTAssertEqual(try ids(Filtro(persone: [1], nodo: 1)), [4, 1])
        XCTAssertEqual(try ids(Filtro(persone: [1], luogo: 1, anno: "2019")), [2, 1])
        XCTAssertEqual(try ids(Filtro(persone: [1], luogo: 1, anno: "2019", genere: "live")), [2])
        XCTAssertEqual(try ids(Filtro(genere: "video")), [3, 8])
        XCTAssertEqual(try ids(Filtro(anno: "2021")), [4, 6])
        XCTAssertEqual(try ids(Filtro(anno: "2017")), [])
    }

    func testLeParoleCercanoInTuttiIPostiETutteInsieme() throws {
        XCTAssertEqual(try ids(Filtro(parole: ["spiaggia"])), [3, 1])
        XCTAssertEqual(try ids(Filtro(parole: ["spiaggia", "cane"])), [3])
        XCTAssertEqual(try ids(Filtro(parole: ["gatti"])), [4, 1])
        XCTAssertEqual(try ids(Filtro(parole: ["gatto"])), [8])
        XCTAssertEqual(try ids(Filtro(parole: ["2019"])), [4, 2, 1])
        XCTAssertEqual(try ids(Filtro(parole: ["monti"])), [3])
        XCTAssertEqual(try ids(Filtro(parole: ["niente"])), [])
    }

    func testISegniSpecialiNonCercanoTutto() throws {
        XCTAssertEqual(try ids(Filtro(parole: ["%"])), [1])
        XCTAssertEqual(try ids(Filtro(parole: ["_"])), [2])
        XCTAssertEqual(try ids(Filtro(parole: ["\\"])), [])
        XCTAssertEqual(try ids(Filtro(parole: ["'"])), [])
        XCTAssertEqual(Filtro.parole(di: "  Gatti  gatti\tNERI "), ["gatti", "neri"])
        XCTAssertEqual(try archivio.cerca("Gatti NERI"), try archivio.scatti(filtro: Filtro(parole: ["gatti", "neri"])))
    }

    func testIGiorniSeguonoIlFiltroEContanoGiusto() throws {
        for f in [Filtro(), Filtro(persone: [1]), Filtro(nodo: 1), Filtro(parole: ["2019"]), Filtro(vecchiePrima: true),
                  Filtro(genere: "video"), Filtro(persone: [1, 2])] {
            let giorni = try archivio.giorni(filtro: f)
            XCTAssertEqual(giorni.map(\.quanti).reduce(0, +), try archivio.quanti(filtro: f))
            var visti: [String?] = []
            for s in try archivio.scatti(filtro: f) where visti.last != .some(s.giorno) { visti.append(s.giorno) }
            XCTAssertEqual(giorni.map(\.giorno), visti)
        }
        XCTAssertEqual(try archivio.giorni(filtro: Filtro(persone: [1])).first?.luoghi, ["Firenze"])
    }

    func testINodiVuotiNonCompaiono() throws {
        XCTAssertEqual(try archivio.nodi(figliDi: nil).map(\.nome), ["Animali", "Mare e monti"])
        XCTAssertEqual(try archivio.nodi(figliDi: 1).map(\.nome), ["Gatti"])
        XCTAssertEqual(try archivio.nodo(5)?.nome, "Cani")
        XCTAssertEqual(try archivio.copertina(nodo: 1)?.id, 4)
        XCTAssertNil(try archivio.copertina(nodo: 4))
    }

    func testLePersoneSenzaFotoNonCompaionoEInsiemeNonContaSeStessa() throws {
        XCTAssertEqual(try archivio.persone().map(\.nome), ["Anna Rossi", "Bruno", "Ossobuco"])
        XCTAssertEqual(try archivio.persona(1)?.dal, "2019-05-01")
        XCTAssertEqual(try archivio.persona(1)?.al, "2021-01-02")
        XCTAssertEqual(try archivio.insieme(a: 1).map(\.persona.nome), ["Bruno"])
        XCTAssertEqual(try archivio.insieme(a: 1).first?.quante, 1)
        XCTAssertEqual(try archivio.insieme(a: 4), [])
    }

    func testTrovatiGuardaLInizioDelleParole() throws {
        XCTAssertEqual(try archivio.trovati("ros").persone.map(\.nome), ["Anna Rossi"])
        XCTAssertEqual(try archivio.trovati("an").persone.map(\.nome), ["Anna Rossi"])
        XCTAssertEqual(try archivio.trovati("oss").persone.map(\.nome), ["Ossobuco"])
        XCTAssertEqual(try archivio.trovati("car").persone, [])
        XCTAssertEqual(try archivio.trovati("gat").nodi.map(\.nome), ["Gatti", "Gatti neri"])
        XCTAssertEqual(try archivio.trovati("ner").nodi.map(\.nome), ["Gatti neri"])
        XCTAssertEqual(try archivio.trovati("can").nodi, [])
        XCTAssertEqual(try archivio.trovati("fir").luoghi.map(\.nome), ["Firenze"])
        XCTAssertEqual(try archivio.trovati("fir").luoghi.first?.quanti, 3)
        XCTAssertEqual(try archivio.trovati("2019").anni, [Anno(anno: "2019", quanti: 2)])
        XCTAssertEqual(try archivio.trovati("201").anni, [])
        XCTAssertEqual(try archivio.trovati("2017").anni, [])
        XCTAssertTrue(try archivio.trovati("   ").vuoto)
        XCTAssertTrue(try archivio.trovati("%").vuoto)
    }

    func testLuoghiAnniDettagliEInformazioni() throws {
        XCTAssertEqual(try archivio.luoghi().map(\.nome), ["Firenze", "Lucca"])
        XCTAssertEqual(try archivio.anni(), [Anno(anno: "2021", quanti: 2), Anno(anno: "2020", quanti: 1),
                                            Anno(anno: "2019", quanti: 2), Anno(anno: "2018", quanti: 1)])
        let d = try archivio.dettagli(2)
        XCTAssertEqual(d.persone.map(\.nome), ["Anna Rossi", "Bruno"])
        XCTAssertEqual(d.nodi, [])
        XCTAssertEqual(try archivio.dettagli(4).nodi.map(\.nome), ["Gatti neri"])
        XCTAssertTrue(archivio.ciSonoParole())
        XCTAssertEqual(archivio.informazioni()["quanti_scatti"], "8")
    }

    func testIlRiassuntoDiUnaPersona() throws {
        let r = try archivio.riassunto(filtro: Filtro(persone: [1]))
        XCTAssertEqual(r.quanti, 3)
        XCTAssertEqual(r.video, 0)
        XCTAssertEqual(r.dal, "2019-05-01")
        XCTAssertEqual(r.al, "2021-01-02")
        XCTAssertEqual(r.anni, [Anno(anno: "2021", quanti: 1), Anno(anno: "2019", quanti: 2)])
        XCTAssertEqual(r.luoghi.map(\.nome), ["Firenze"])
        XCTAssertEqual(r.luoghi.first?.quanti, 3)
        XCTAssertEqual(r.persone.map(\.persona.nome), ["Bruno"])
        XCTAssertEqual(r.persone.first?.quante, 1)
        XCTAssertEqual(r.nodi.map(\.nodo.nome), ["Animali"])
        XCTAssertEqual(r.nodi.first?.quante, 2)
    }

    func testIlRiassuntoNonMetteLaPersonaFraLeSueCompagnie() throws {
        let r = try archivio.riassunto(filtro: Filtro(persone: [2]))
        XCTAssertEqual(r.quanti, 2)
        XCTAssertEqual(r.video, 1)
        XCTAssertEqual(r.persone.map(\.persona.nome), ["Anna Rossi"])
        XCTAssertEqual(r.luoghi.map(\.nome), ["Firenze", "Lucca"])
        XCTAssertEqual(r.nodi.map(\.nodo.nome), ["Mare e monti"])
    }

    func testIlRiassuntoDiUnNodoGuardaIFigli() throws {
        let r = try archivio.riassunto(filtro: Filtro(nodo: 1), figliDi: 1)
        XCTAssertEqual(r.quanti, 3)
        XCTAssertEqual(r.anni, [Anno(anno: "2021", quanti: 2), Anno(anno: "2019", quanti: 1)])
        XCTAssertEqual(r.luoghi.map(\.nome), ["Firenze"])
        XCTAssertEqual(r.persone.map(\.persona.nome), ["Anna Rossi"])
        XCTAssertEqual(r.persone.first?.quante, 2)
        XCTAssertEqual(r.nodi.map(\.nodo.nome), ["Gatti"])
        XCTAssertEqual(r.nodi.first?.quante, 2)
        XCTAssertEqual(try archivio.nodi(filtro: Filtro(), figliDi: 2).map(\.nodo.nome), ["Gatti neri"])
        XCTAssertEqual(try archivio.nodi(filtro: Filtro()).map(\.nodo.nome), ["Animali", "Mare e monti"])
    }

    func testUnNodoVuotoHaUnRiassuntoVuoto() throws {
        let r = try archivio.riassunto(filtro: Filtro(nodo: 4))
        XCTAssertEqual(r.quanti, 0)
        XCTAssertNil(r.dal)
        XCTAssertNil(r.al)
        XCTAssertEqual(r.anni, [])
        XCTAssertEqual(r.luoghi, [])
        XCTAssertEqual(r.persone, [])
        XCTAssertEqual(r.nodi, [])
        XCTAssertEqual(try archivio.copertine(filtro: Filtro(nodo: 4)), [])
    }

    func testLeCopertineVengonoDaGiorniDiversi() throws {
        XCTAssertEqual(try archivio.copertine(filtro: Filtro()).map(\.id), [4, 3, 2, 7])
        XCTAssertEqual(try archivio.copertine(filtro: Filtro(nodo: 1)).map(\.id), [4, 1, 6])
        XCTAssertEqual(try archivio.copertine(filtro: Filtro(), quante: 2).map(\.id), [4, 3])
    }

    func testLePersoneInOrdineDiNome() throws {
        XCTAssertEqual(try archivio.personePerNome().map(\.nome), ["Anna Rossi", "Bruno", "Ossobuco"])
    }

    func pescati(_ m: Mescola) throws -> Set<Int64> { Set(try archivio.pescati(mescola: m).map(\.id)) }

    func testAcasoSenzaSceltePescaTutto() throws {
        XCTAssertTrue(Mescola().tutto)
        XCTAssertEqual(try pescati(Mescola()), [1, 2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(try archivio.quanti(mescola: Mescola()), 8)
    }

    func testAcasoITipiSiSommano() throws {
        XCTAssertEqual(try pescati(Mescola(generi: ["video"])), [3, 8])
        XCTAssertEqual(try pescati(Mescola(generi: ["foto", "video"])), [1, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(try pescati(Mescola(generi: ["live", "video"])), [2, 3, 8])
        XCTAssertFalse(Mescola(generi: ["foto"]).tutto)
    }

    func testAcasoINodiPrendonoIlRamoEBastaUno() throws {
        XCTAssertEqual(try pescati(Mescola(nodi: [2])), [1, 4])
        XCTAssertEqual(try pescati(Mescola(nodi: [2, 6])), [1, 3, 4])
        XCTAssertEqual(try pescati(Mescola(nodi: [5])), [])
    }

    func testAcasoUnNodoFiglioPrendeSoloIlSuoRamo() throws {
        XCTAssertEqual(try archivio.nodi(figliDi: 2).map(\.id), [3])
        XCTAssertEqual(try pescati(Mescola(nodi: [3])), [4])
        XCTAssertEqual(try archivio.quanti(mescola: Mescola(nodi: [3])), 1)
        XCTAssertEqual(try pescati(Mescola(nodi: [2])), [1, 4])
        XCTAssertEqual(try pescati(Mescola(nodi: [3, 6])), [3, 4])
        XCTAssertEqual(try pescati(Mescola(nodi: [1, 3])), try pescati(Mescola(nodi: [1])))
        XCTAssertEqual(try pescati(Mescola(generi: ["video"], nodi: [3])), [])
    }

    func testAcasoBastaUnaDellePersone() throws {
        XCTAssertEqual(try pescati(Mescola(persone: [1, 2])), [1, 2, 3, 4])
        XCTAssertEqual(try pescati(Mescola(persone: [4])), [7])
    }

    func testAcasoGliAnniLascianoFuoriISenzaData() throws {
        XCTAssertEqual(try pescati(Mescola(anni: ["2019", "2020"])), [1, 2, 3])
        XCTAssertEqual(try pescati(Mescola(generi: ["foto"], persone: [1])), [1, 4])
        XCTAssertEqual(try pescati(Mescola(generi: ["video"], anni: ["2019"])), [])
    }

    func testAcasoIContiPerTipoNonGuardanoIlTipoScelto() throws {
        XCTAssertEqual(try archivio.quantiPerGenere(mescola: Mescola()), ["foto": 5, "live": 1, "video": 2])
        XCTAssertEqual(try archivio.quantiPerGenere(mescola: Mescola(generi: ["video"], persone: [1])),
                       ["foto": 2, "live": 1, "video": 0])
    }

    func testAcasoGliScattiTornanoNellOrdineChiesto() throws {
        XCTAssertEqual(try archivio.scatti(numeri: [4, 1, 3, 99]).map(\.id), [4, 1, 3])
        XCTAssertEqual(try archivio.scatti(numeri: []).map(\.id), [])
        XCTAssertEqual(try archivio.pescati(mescola: Mescola(generi: ["live"])).map(\.impronta), ["b"])
    }

    func testAcasoRimescolaEUnaPermutazioneRipetibile() {
        let numeri = Array(1...50)
        let a = Mescola.rimescola(numeri, seme: 7)
        XCTAssertEqual(a, Mescola.rimescola(numeri, seme: 7))
        XCTAssertNotEqual(a, Mescola.rimescola(numeri, seme: 8))
        XCTAssertNotEqual(a, numeri)
        XCTAssertEqual(a.sorted(), numeri)
        XCTAssertEqual(Mescola.rimescola([Int](), seme: 1), [])
        XCTAssertEqual(Mescola.rimescola([3], seme: 1), [3])
    }
}
