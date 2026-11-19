import CryptoKit
import Foundation
import SQLite3
import XCTest
@testable import VisoreKit

final class RitornoTests: XCTestCase {

    let radice = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    let a = String(repeating: "a", count: 64)
    let b = String(repeating: "b", count: 64)
    let c = String(repeating: "c", count: 64)

    var cartella: URL!

    override func setUpWithError() throws {
        cartella = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: cartella)
    }

    func chiave() throws -> Chiave {
        try Chiave(byte: Data(esadecimale: "2468f675852760e32f87de5b3c6243d45feda9e045bcb7bf0db159335b459ce4")!)
    }

    var dove: URL { cartella.appendingPathComponent("ritorno.db") }

    func impronta(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }

    func testLaCifraturaEUgualeAQuellaDelComputer() throws {
        let k = try chiave()
        let prefisso = Data(1...8)
        let lungo = Data((0..<2_500_000).map { UInt8($0 % 251) })
        let casi: [(Data, Int, String)] = [
            (Data("ciao dal telefono".utf8), 155, "0bffb24bf1f23149e6f8d7d2c2df507c0ca7618ffed24111418fb6976ae0722a"),
            (Data(), 137, "2f8c69680442eb19db682c3e8f508873ce09ae51fdcb3c5cfb2c042f48659074"),
            (lungo, 2_500_175, "ceedc57de7732dd8606bfcff78a4abb5d04847a54883ce6a678089022a7b2748"),
        ]
        for (chiaro, peso, attesa) in casi {
            let chiuso = try k.cifra(chiaro, posto: "ritorno.db", prefisso: prefisso)
            XCTAssertEqual(chiuso.count, peso)
            XCTAssertEqual(impronta(chiuso), attesa)
            XCTAssertEqual(try k.decifra(chiuso, posto: "ritorno.db"), chiaro)
        }
    }

    func testLaCifraturaNonSiApreAlPostoSbagliatoNeSeToccata() throws {
        let k = try chiave()
        var chiuso = try k.cifra(Data("cuori".utf8), posto: "ritorno.db")
        XCTAssertThrowsError(try k.decifra(chiuso, posto: "dati.db"))
        chiuso[chiuso.count - 1] ^= 1
        XCTAssertThrowsError(try k.decifra(chiuso, posto: "ritorno.db"))
        let altra = try k.cifra(Data("cuori".utf8), posto: "ritorno.db")
        let terza = try k.cifra(Data("cuori".utf8), posto: "ritorno.db")
        XCTAssertNotEqual(altra, terza)
    }

    func leggiComeIlComputer(_ k: Chiave) throws -> [String: [[String?]]] {
        let chiaro = try k.decifra(Data(contentsOf: dove), posto: "ritorno.db")
        let file = cartella.appendingPathComponent("letto.db")
        try chiaro.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(file.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var uscita: [String: [[String?]]] = [:]
        let domande = [
            "cuori": "SELECT impronta, messo_il FROM cuori ORDER BY impronta",
            "raccolte": "SELECT id, nome, creata_il FROM raccolte ORDER BY id",
            "raccolte_scatti": "SELECT raccolta_id, impronta FROM raccolte_scatti ORDER BY raccolta_id, impronta",
            "diario": "SELECT aperto_il, durata_s, quante_foto FROM diario ORDER BY aperto_il",
        ]
        for (nome, sql) in domande {
            var s: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &s, nil), SQLITE_OK)
            var righe: [[String?]] = []
            while sqlite3_step(s) == SQLITE_ROW {
                righe.append((0..<sqlite3_column_count(s)).map { i in
                    sqlite3_column_text(s, i).map { String(cString: $0) }
                })
            }
            sqlite3_finalize(s)
            uscita[nome] = righe
        }
        return uscita
    }

    func testIlPrimoAvvioRiprendeLaScortaEToglieQuelliTolti() throws {
        let k = try chiave()
        let scorta = Scorta(cuori: [Cuore(impronta: a, messoIl: "2021-05-01T10:00:00Z"),
                                    Cuore(impronta: b, messoIl: "2021-05-01T10:00:00Z")],
                            tolti: [Cuore(impronta: b, messoIl: "2022-01-01T00:00:00Z")],
                            raccolte: [Raccolta(numero: 7, nome: "stampa", creataIl: "2021-05-02T09:00:00Z",
                                                impronte: [a, c])])
        let r = try Ritorno(dove: dove, chiave: k, scorta: scorta)
        XCTAssertNil(r.guaio)
        XCTAssertEqual(r.cuori(), [a])
        XCTAssertEqual(r.raccolte().map(\.nome), ["stampa"])
        XCTAssertEqual(r.raccolte().first?.impronte, [a, c])
        let letto = try leggiComeIlComputer(k)
        XCTAssertEqual(letto["cuori"], [[a, "2021-05-01T10:00:00Z"]])
        XCTAssertEqual(letto["raccolte"], [["7", "stampa", "2021-05-02T09:00:00Z"]])
        XCTAssertEqual(letto["raccolte_scatti"], [["7", a], ["7", c]])
    }

    func testSenzaScortaENienteDiSuoNonScriveNiente() throws {
        _ = try Ritorno(dove: dove, chiave: try chiave(), scorta: Scorta())
        XCTAssertFalse(FileManager.default.fileExists(atPath: dove.path))
    }

    func testLaScortaNonSiGuardaSeIlTelefonoHaGiaIlSuo() throws {
        let k = try chiave()
        let r = try Ritorno(dove: dove, chiave: k, scorta: Scorta())
        try r.metti(c, quando: "2025-01-01T00:00:00Z")
        try r.togli(c)
        let scorta = Scorta(cuori: [Cuore(impronta: a, messoIl: "2021-05-01T10:00:00Z")])
        let dopo = try Ritorno(dove: dove, chiave: k, scorta: scorta)
        XCTAssertEqual(dopo.cuori(), [])
    }

    func testOgniGestoESalvatoSubitoESiRilegge() throws {
        let k = try chiave()
        let r = try Ritorno(dove: dove, chiave: k, scorta: Scorta())
        try r.metti(a, quando: "2025-03-01T08:00:00Z")
        XCTAssertEqual(try leggiComeIlComputer(k)["cuori"], [[a, "2025-03-01T08:00:00Z"]])
        try r.metti(a, quando: "2026-03-01T08:00:00Z")
        try r.metti(b, quando: "2025-03-02T08:00:00Z")
        try r.togli(b)
        let numero = try r.nuovaRaccolta("  Mare  ", impronte: [a, b], quando: "2025-04-01T00:00:00Z")
        try r.aggiungi([c, a], a: numero)
        try r.togli([b], da: numero)
        try r.rinomina(numero, in: "Mare 2025")
        let seconda = try r.nuovaRaccolta("Neve", quando: "2025-05-01T00:00:00Z")
        try r.apertura("2025-06-01T10:00:00Z", durataS: 42, quanteFoto: 3)
        try r.butta(seconda)
        let letto = try leggiComeIlComputer(k)
        XCTAssertEqual(letto["cuori"], [[a, "2025-03-01T08:00:00Z"]])
        XCTAssertEqual(letto["raccolte"], [[String(numero), "Mare 2025", "2025-04-01T00:00:00Z"]])
        XCTAssertEqual(letto["raccolte_scatti"], [[String(numero), a], [String(numero), c]])
        XCTAssertEqual(letto["diario"], [["2025-06-01T10:00:00Z", "42", "3"]])
        XCTAssertEqual(r.diarioDal(), "2025-06-01T10:00:00Z")
        XCTAssertEqual(r.aperture(), 1)
        let riaperto = try Ritorno(dove: dove, chiave: k, scorta: Scorta(cuori: [Cuore(impronta: c, messoIl: nil)]))
        XCTAssertEqual(riaperto.cuori(), [a])
        XCTAssertEqual(riaperto.raccolte().map(\.nome), ["Mare 2025"])
        let resti = try FileManager.default.contentsOfDirectory(atPath: cartella.path)
        XCTAssertEqual(resti, ["ritorno.db"])
    }

    func testUnaRaccoltaSenzaNomeNonSiFa() throws {
        let r = try Ritorno(dove: dove, chiave: try chiave(), scorta: Scorta())
        XCTAssertThrowsError(try r.nuovaRaccolta("   ")) { XCTAssertEqual($0 as? ErroreRitorno, .nomeVuoto) }
        XCTAssertEqual(r.raccolte(), [])
    }

    func testIlCuoreTogliatoDalComputerSparisceSoloSeMessoPrima() throws {
        let k = try chiave()
        let r = try Ritorno(dove: dove, chiave: k, scorta: Scorta())
        try r.metti(a, quando: "2025-01-01T00:00:00Z")
        try r.metti(b, quando: "2026-12-01T00:00:00Z")
        let tolti = [Cuore(impronta: a, messoIl: "2026-01-01T00:00:00Z"),
                     Cuore(impronta: b, messoIl: "2026-01-01T00:00:00Z"),
                     Cuore(impronta: c, messoIl: "2026-01-01T00:00:00Z")]
        let riaperto = try Ritorno(dove: dove, chiave: k, scorta: Scorta(tolti: tolti))
        XCTAssertEqual(riaperto.cuori(), [b])
        XCTAssertEqual(try leggiComeIlComputer(k)["cuori"], [[b, "2026-12-01T00:00:00Z"]])
    }

    func testIlFileRovinatoSiSpostaAccantoESiRipartDallaScorta() throws {
        let k = try chiave()
        try Data(repeating: 9, count: 300).write(to: dove)
        let r = try Ritorno(dove: dove, chiave: k, scorta: Scorta(cuori: [Cuore(impronta: a, messoIl: nil)]))
        XCTAssertNotNil(r.guaio)
        XCTAssertEqual(r.cuori(), [a])
        let resti = try FileManager.default.contentsOfDirectory(atPath: cartella.path)
        XCTAssertEqual(resti.count, 2)
        XCTAssertTrue(resti.contains { $0.hasPrefix("ritorno.db.illeggibile-") })
        let accanto = resti.first { $0.hasPrefix("ritorno.db.illeggibile-") }!
        XCTAssertEqual(try Data(contentsOf: cartella.appendingPathComponent(accanto)), Data(repeating: 9, count: 300))
    }

    func testUnaChiaveDiversaNonLeggeEdNonCancella() throws {
        let k = try chiave()
        let r = try Ritorno(dove: dove, chiave: k, scorta: Scorta())
        try r.metti(a)
        let prima = try Data(contentsOf: dove)
        let altra = try Chiave(byte: Data(repeating: 1, count: 32))
        let estranea = try Ritorno(dove: dove, chiave: altra, scorta: Scorta())
        XCTAssertNotNil(estranea.guaio)
        let resti = try FileManager.default.contentsOfDirectory(atPath: cartella.path)
        let accanto = resti.first { $0.hasPrefix("ritorno.db.illeggibile-") }!
        XCTAssertEqual(try Data(contentsOf: cartella.appendingPathComponent(accanto)), prima)
    }

    func testSeNonSiScriveIlGestoNonResta() throws {
        let k = try chiave()
        let r = try Ritorno(dove: dove, chiave: k, scorta: Scorta())
        try r.metti(a)
        let prima = try Data(contentsOf: dove)
        try FileManager.default.createDirectory(at: cartella.appendingPathComponent("ritorno.db.parziale"),
                                                withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cartella.appendingPathComponent("ritorno.db.parziale/x"),
                                                withIntermediateDirectories: true)
        XCTAssertThrowsError(try r.metti(b)) { XCTAssertEqual($0 as? ErroreRitorno, .nonScritto) }
        XCTAssertEqual(r.cuori(), [a])
        XCTAssertEqual(try Data(contentsOf: dove), prima)
    }

    func testIlPacchettoDiProvaPortaLaScortaGiusta() throws {
        let p = try Pacchetto(cartella: radice.appendingPathComponent("Prova"), password: "tre parole che ricordi")
        let dati = try Data(contentsOf: radice.appendingPathComponent("Prova-attesa.json"))
        let attesa = (try JSONSerialization.jsonObject(with: dati) as! [String: Any])["scorta"] as! [String: Any]
        let scorta = p.archivio.scorta()
        let cuori = attesa["cuori"] as! [[String: String]]
        XCTAssertEqual(scorta.cuori, cuori.map { Cuore(impronta: $0["impronta"]!, messoIl: $0["messo_il"]) })
        let tolti = attesa["tolti"] as! [[String: String]]
        XCTAssertEqual(scorta.tolti, tolti.map { Cuore(impronta: $0["impronta"]!, messoIl: $0["tolto_il"]) })
        let raccolte = attesa["raccolte"] as! [[String: Any]]
        XCTAssertEqual(scorta.raccolte.map(\.nome), raccolte.map { $0["nome"] as! String })
        XCTAssertEqual(scorta.raccolte.map(\.impronte), raccolte.map { $0["impronte"] as! [String] })
        let r = try p.ritorno(in: dove)
        XCTAssertEqual(r.cuori(), Set(cuori.map { $0["impronta"]! }))
        let scatti = try p.archivio.scatti(filtro: Filtro(impronte: Array(r.cuori())))
        XCTAssertEqual(Set(scatti.map(\.impronta)), r.cuori())
        XCTAssertTrue(try p.archivio.scatti().allSatisfy { $0.impronta.count == 64 })
        XCTAssertEqual(try p.archivio.quanti(filtro: Filtro(impronte: [])), 0)
    }
}
