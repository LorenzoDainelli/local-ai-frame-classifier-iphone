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
        for s in scatti {
            XCTAssertFalse(try p.apri(s.posto).isEmpty)
        }
    }

    func testLaPasswordSbagliataNonApreIlPacchettoDelPc() {
        XCTAssertThrowsError(try Pacchetto(cartella: cartella, password: "tre parole che ricordo")) {
            XCTAssertEqual($0 as? ErroreVisore, .passwordSbagliata)
        }
    }
}
