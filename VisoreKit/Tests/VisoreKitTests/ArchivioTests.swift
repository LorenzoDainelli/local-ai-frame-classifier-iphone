import Foundation
import SQLite3
import XCTest
@testable import VisoreKit

final class ArchivioTests: XCTestCase {

    func databaseDiProva() throws -> Data {
        let dove = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        defer { try? FileManager.default.removeItem(at: dove) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dove.path, &db), SQLITE_OK)
        let sql = """
        CREATE TABLE persone (id INTEGER PRIMARY KEY, nome TEXT NOT NULL, volto TEXT, quanti INTEGER NOT NULL);
        INSERT INTO persone VALUES (1, 'Anna', NULL, 3), (2, 'Bruno', 'volti/ab/cd', 7);
        """
        XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        return try Data(contentsOf: dove)
    }

    func cartellaTemporanea() throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path))
    }

    func testIlDatabaseSiApreInMemoriaSenzaFileSulDisco() throws {
        let dati = try databaseDiProva()
        let prima = try cartellaTemporanea()
        let archivio = try Archivio(dati: dati)
        XCTAssertEqual(try cartellaTemporanea(), prima)
        let persone = try archivio.persone()
        XCTAssertEqual(persone.map(\.nome), ["Bruno", "Anna"])
        XCTAssertEqual(persone.first?.volto, "volti/ab/cd")
    }

    func testDatiCheNonSonoUnDatabaseVengonoRifiutati() {
        XCTAssertThrowsError(try Archivio(dati: Data(repeating: 7, count: 8192))) {
            XCTAssertEqual($0 as? ErroreVisore, .archivioIlleggibile)
        }
        XCTAssertThrowsError(try Archivio(dati: Data())) {
            XCTAssertEqual($0 as? ErroreVisore, .archivioIlleggibile)
        }
    }
}
