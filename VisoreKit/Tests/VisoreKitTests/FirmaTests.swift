import Foundation
import XCTest
@testable import VisoreKit

final class FirmaTests: XCTestCase {

    func profilo(scade: String) -> Data {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>AppIDName</key><string>Visore</string>
        <key>ExpirationDate</key><date>\(scade)</date>
        <key>Name</key><string>finto</string>
        </dict></plist>
        """
        return Data([0x30, 0x82, 0x2A, 0x10, 0x06, 0x09, 0x00, 0xFF]) + Data(plist.utf8) + Data([0xA0, 0x82, 0x00, 0x3C, 0x3C])
    }

    var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }

    func data(_ testo: String) -> Date {
        ISO8601DateFormatter().date(from: testo)!
    }

    func testLaScadenzaSiLeggeDalProfiloFirmato() {
        XCTAssertEqual(Firma.scadenza(profilo: profilo(scade: "2026-11-26T10:00:00Z")), data("2026-11-26T10:00:00Z"))
    }

    func testUnProfiloRovinatoNonDaNessunaData() {
        XCTAssertNil(Firma.scadenza(profilo: Data("niente qui".utf8)))
        XCTAssertNil(Firma.scadenza(profilo: Data("<?xml senza fine".utf8)))
        XCTAssertNil(Firma.scadenza(bundle: Bundle(for: FirmaTests.self)))
    }

    func testIGiorniSiContanoACalendario() {
        let adesso = data("2026-11-19T22:30:00Z")
        XCTAssertEqual(Firma.giorni(fino: data("2026-11-26T08:00:00Z"), da: adesso, calendario: calendario), 7)
        XCTAssertEqual(Firma.aParole(fino: data("2026-11-26T08:00:00Z"), da: adesso, calendario: calendario),
                       "La firma scade fra 7 giorni.")
        XCTAssertEqual(Firma.aParole(fino: data("2026-11-20T20:00:00Z"), da: adesso, calendario: calendario),
                       "La firma scade domani.")
        XCTAssertEqual(Firma.aParole(fino: data("2026-11-19T22:50:00Z"), da: adesso, calendario: calendario),
                       "La firma scade oggi: rinnovala con AltStore.")
        XCTAssertEqual(Firma.aParole(fino: data("2026-11-19T20:00:00Z"), da: adesso, calendario: calendario),
                       "La firma è scaduta: rinnovala con AltStore.")
    }
}
