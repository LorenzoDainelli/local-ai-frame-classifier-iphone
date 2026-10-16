import CryptoKit
import XCTest
@testable import VisoreKit

final class CifraturaTests: XCTestCase {

    let cartella = Bundle.module.url(forResource: "Vettori", withExtension: nil)!

    func elenco() throws -> [String: [String: Any]] {
        let dati = try Data(contentsOf: cartella.appendingPathComponent("elenco.json"))
        return try JSONSerialization.jsonObject(with: dati) as! [String: [String: Any]]
    }

    func testLaPasswordGiustaDaLaStessaChiaveDelComputer() throws {
        let carta = try Carta.leggi(cartella: cartella)
        let chiave = try Chiave.dallaPassword("cavallo-finto-42", carta: carta)
        let attesa = try String(contentsOf: cartella.appendingPathComponent("chiave.hex"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(chiave.chiave.withUnsafeBytes { Data($0) }, Data(esadecimale: attesa))
    }

    func testLaPasswordSbagliataNonApre() throws {
        let carta = try Carta.leggi(cartella: cartella)
        XCTAssertThrowsError(try Chiave.dallaPassword("cavallo-finto-43", carta: carta)) {
            XCTAssertEqual($0 as? ErroreVisore, .passwordSbagliata)
        }
    }

    func testOgniFileSiApreUgualeAlChiaro() throws {
        let carta = try Carta.leggi(cartella: cartella)
        let chiave = try Chiave.dallaPassword("cavallo-finto-42", carta: carta)
        for (nome, info) in try elenco() {
            let cifrato = try Data(contentsOf: cartella.appendingPathComponent("\(nome).bin"))
            let chiaro = try chiave.decifra(cifrato, posto: info["posto"] as! String)
            XCTAssertEqual(chiaro.count, info["dimensione"] as! Int)
            let impronta = SHA256.hash(data: chiaro).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(impronta, info["impronta"] as! String)
        }
    }

    func testUnFileSpostatoDiPostoNonSiApre() throws {
        let carta = try Carta.leggi(cartella: cartella)
        let chiave = try Chiave.dallaPassword("cavallo-finto-42", carta: carta)
        let cifrato = try Data(contentsOf: cartella.appendingPathComponent("corto.bin"))
        XCTAssertThrowsError(try chiave.decifra(cifrato, posto: "foto/ab/lungo"))
    }

    func testUnByteCambiatoNonSiApre() throws {
        let carta = try Carta.leggi(cartella: cartella)
        let chiave = try Chiave.dallaPassword("cavallo-finto-42", carta: carta)
        var cifrato = try Data(contentsOf: cartella.appendingPathComponent("lungo.bin"))
        cifrato[cifrato.count - 40] ^= 1
        XCTAssertThrowsError(try chiave.decifra(cifrato, posto: "foto/ab/lungo"))
    }

    func testUnFileTroncatoNonSiApre() throws {
        let carta = try Carta.leggi(cartella: cartella)
        let chiave = try Chiave.dallaPassword("cavallo-finto-42", carta: carta)
        let cifrato = try Data(contentsOf: cartella.appendingPathComponent("lungo.bin"))
        XCTAssertThrowsError(try chiave.decifra(cifrato.dropLast(1024 * 1024 / 2), posto: "foto/ab/lungo"))
    }

    func testIlFileGrandeSiApreAncheAPezzi() throws {
        let carta = try Carta.leggi(cartella: cartella)
        let chiave = try Chiave.dallaPassword("cavallo-finto-42", carta: carta)
        let dove = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dove) }
        try chiave.decifraFile(da: cartella.appendingPathComponent("lungo.bin"), a: dove, posto: "foto/ab/lungo")
        let tutto = try chiave.decifra(Data(contentsOf: cartella.appendingPathComponent("lungo.bin")), posto: "foto/ab/lungo")
        XCTAssertEqual(try Data(contentsOf: dove), tutto)
        let altro = dove.appendingPathExtension("altro")
        XCTAssertThrowsError(try chiave.decifraFile(da: cartella.appendingPathComponent("lungo.bin"), a: altro, posto: "foto/ab/corto"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: altro.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: altro.appendingPathExtension("parziale").path))
    }

    func testIPostiFuoriDalPacchettoSonoRifiutati() {
        XCTAssertTrue(Pacchetto.postoSicuro("foto/ab/0123"))
        XCTAssertFalse(Pacchetto.postoSicuro("../dati.db"))
        XCTAssertFalse(Pacchetto.postoSicuro("foto/../../x"))
        XCTAssertFalse(Pacchetto.postoSicuro("dati.db"))
        XCTAssertFalse(Pacchetto.postoSicuro("foto//x"))
    }
}
