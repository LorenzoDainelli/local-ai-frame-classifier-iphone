import Foundation
import XCTest
@testable import VisoreKit

final class LettoreCifratoTests: XCTestCase {

    let cartella = Bundle.module.url(forResource: "Vettori", withExtension: nil)!

    func chiave() throws -> Chiave {
        try Chiave.dallaPassword("cavallo-finto-42", carta: try Carta.leggi(cartella: cartella))
    }

    func testLeggereAPezziDaGliStessiByteDiLeggereTutto() throws {
        let k = try chiave()
        let url = cartella.appendingPathComponent("lungo.bin")
        let tutto = try k.decifra(Data(contentsOf: url), posto: "foto/ab/lungo")
        let lettore = try LettoreCifrato(chiave: k, url: url, posto: "foto/ab/lungo")
        XCTAssertEqual(lettore.dimensione, tutto.count)
        let pezzi: [(Int, Int)] = [(0, 10), (Chiave.blocco - 5, 10), (Chiave.blocco, 123),
                                   (tutto.count - 7, 50), (3, 0), (tutto.count, 10), (0, tutto.count)]
        for (da, quanti) in pezzi {
            let atteso = tutto[tutto.startIndex + da..<tutto.startIndex + min(tutto.count, da + quanti)]
            XCTAssertEqual(try lettore.leggi(da: da, quanti: quanti), Data(atteso), "da \(da)")
        }
        XCTAssertEqual(try lettore.leggi(da: 0, quanti: 10), Data(tutto.prefix(10)))
    }

    func testIlFileVuotoECortoSiLeggono() throws {
        let k = try chiave()
        let vuoto = try LettoreCifrato(chiave: k, url: cartella.appendingPathComponent("vuoto.bin"), posto: "foto/ab/vuoto")
        XCTAssertEqual(vuoto.dimensione, 0)
        XCTAssertEqual(try vuoto.leggi(da: 0, quanti: 100), Data())
        let corto = try LettoreCifrato(chiave: k, url: cartella.appendingPathComponent("corto.bin"), posto: "foto/ab/corto")
        XCTAssertEqual(try corto.leggi(da: 0, quanti: 100).count, 21)
    }

    func testIlPostoSbagliatoOUnByteCambiatoNonSiAprono() throws {
        let k = try chiave()
        let url = cartella.appendingPathComponent("lungo.bin")
        let altrove = try LettoreCifrato(chiave: k, url: url, posto: "foto/ab/corto")
        XCTAssertThrowsError(try altrove.leggi(da: 0, quanti: 1))
        var dati = try Data(contentsOf: url)
        dati[dati.count - 40] ^= 1
        let rotto = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: rotto) }
        try dati.write(to: rotto)
        let lettore = try LettoreCifrato(chiave: k, url: rotto, posto: "foto/ab/lungo")
        XCTAssertNoThrow(try lettore.leggi(da: 0, quanti: 10))
        XCTAssertThrowsError(try lettore.leggi(da: Chiave.blocco, quanti: 10))
    }

    func testUnFileTroncatoNonSiApreNemmenoAPezzi() throws {
        let k = try chiave()
        let dati = try Data(contentsOf: cartella.appendingPathComponent("lungo.bin"))
        let corto = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: corto) }
        try dati.dropLast(100).write(to: corto)
        XCTAssertThrowsError(try LettoreCifrato(chiave: k, url: corto, posto: "foto/ab/lungo"))
    }
}
