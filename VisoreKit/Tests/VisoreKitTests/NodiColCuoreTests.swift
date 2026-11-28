import XCTest
@testable import VisoreKit

final class NodiColCuoreTests: XCTestCase {
    func testMettereEToglierlo() {
        var t = ""
        t = NodiColCuore.cambia(t, 7)
        XCTAssertEqual(t, "7")
        t = NodiColCuore.cambia(t, 3)
        XCTAssertEqual(NodiColCuore.leggi(t), [7, 3])
        XCTAssertTrue(NodiColCuore.ha(t, 3))
        t = NodiColCuore.cambia(t, 7)
        XCTAssertEqual(NodiColCuore.leggi(t), [3])
        XCTAssertFalse(NodiColCuore.ha(t, 7))
    }

    func testUnTestoRovinatoNonRompeNiente() {
        XCTAssertEqual(NodiColCuore.leggi(""), [])
        XCTAssertEqual(NodiColCuore.leggi("4,,x, 9,4"), [4, 9])
        XCTAssertEqual(NodiColCuore.scrivi([5, 5, 2]), "5,2")
    }

    func testOgniArchivioHaIlSuo() {
        XCTAssertNotEqual(NodiColCuore.chiave(archivio: "a"), NodiColCuore.chiave(archivio: "b"))
    }
}
