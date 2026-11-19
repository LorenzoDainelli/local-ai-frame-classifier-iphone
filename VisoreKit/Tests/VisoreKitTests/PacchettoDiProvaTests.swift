import Foundation
import XCTest
@testable import VisoreKit

final class PacchettoDiProvaTests: XCTestCase {

    let radice = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    var cartella: URL { radice.appendingPathComponent("Prova") }

    func atteso() throws -> [String: Any] {
        let dati = try Data(contentsOf: radice.appendingPathComponent("Prova-attesa.json"))
        return try JSONSerialization.jsonObject(with: dati) as! [String: Any]
    }

    func testIlPacchettoDelPcSiApreEDiceLeStesseCose() throws {
        let p = try Pacchetto(cartella: cartella, password: "tre parole che ricordi")
        let a = try atteso()
        XCTAssertEqual(p.carta.quantiScatti, a["quanti"] as? Int)
        let scatti = try p.archivio.scatti()
        let attesi = a["scatti"] as! [[String: Any]]
        XCTAssertEqual(scatti.map(\.id), attesi.map { Int64($0["id"] as! Int) })
        XCTAssertEqual(scatti.map(\.posto), attesi.map { $0["posto"] as! String })
        XCTAssertEqual(scatti.map(\.genere), attesi.map { $0["genere"] as! String })
        XCTAssertEqual(Set(try p.archivio.persone().map(\.nome)), Set(a["persone"] as! [String]))
        var nomi: [String] = []
        var daGuardare: [Int64?] = [nil]
        while let genitore = daGuardare.popLast() {
            for n in try p.archivio.nodi(figliDi: genitore) {
                nomi.append(n.nome)
                daGuardare.append(n.id)
            }
        }
        XCTAssertEqual(Set(nomi), Set(a["nodi"] as! [String]))
        let giorni = try p.archivio.giorni()
        let giorniAttesi = a["giorni"] as! [[String: Any]]
        XCTAssertEqual(giorni.map(\.giorno), giorniAttesi.map { $0["giorno"] as? String })
        XCTAssertEqual(giorni.map(\.quanti), giorniAttesi.map { $0["quanti"] as! Int })
        XCTAssertEqual(giorni.map { Set($0.luoghi) }, giorniAttesi.map { Set($0["luoghi"] as! [String]) })
        XCTAssertEqual(giorni.map(\.quanti).reduce(0, +), scatti.count)
        for s in scatti {
            XCTAssertFalse(try p.apri(s.posto).isEmpty)
            let lettore = try p.lettore(s.posto)
            XCTAssertEqual(try lettore.leggi(da: 0, quanti: lettore.dimensione), try p.apri(s.posto))
        }
    }

    func testRicercaEDettagliDiconoQuelloCheDiceIlPc() throws {
        let p = try Pacchetto(cartella: cartella, password: "tre parole che ricordi")
        let a = try atteso()
        let dettagli = a["dettagli"] as! [String: Any]
        let d = try p.archivio.dettagli(Int64(dettagli["id"] as! Int))
        XCTAssertEqual(d.nodi.map(\.nome), (dettagli["nodi"] as! [[Any]]).map { $0[0] as! String })
        XCTAssertEqual(d.persone.map(\.nome), dettagli["persone"] as! [String])
        for chiave in ["cerca", "cerca_anno"] {
            let c = a[chiave] as! [String: Any]
            let t = try p.archivio.trovati(c["testo"] as! String)
            XCTAssertEqual(t.persone.map(\.nome), c["persone"] as! [String])
            XCTAssertEqual(t.nodi.map(\.nome), c["nodi"] as! [String])
            XCTAssertEqual(t.anni.map { [$0.anno, String($0.quanti)] },
                           (c["date"] as! [[Any]]).map { ["\($0[0])", "\($0[1])"] })
        }
        XCTAssertFalse(p.archivio.ciSonoParole())
        XCTAssertEqual(try p.archivio.insieme(a: 1).map(\.persona.nome), ["Bruno"])
        XCTAssertEqual(try p.archivio.persone().map(\.nome).sorted(), ["Ada", "Bruno"])
    }

    func testLaPasswordSbagliataNonApreIlPacchettoDelPc() {
        XCTAssertThrowsError(try Pacchetto(cartella: cartella, password: "tre parole che ricordo")) {
            XCTAssertEqual($0 as? ErroreVisore, .passwordSbagliata)
        }
    }
}
