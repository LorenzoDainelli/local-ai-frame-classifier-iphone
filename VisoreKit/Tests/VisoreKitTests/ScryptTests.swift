import Foundation
import XCTest
@testable import VisoreKit

final class ScryptTests: XCTestCase {
    private func esa(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

    func testIVettoriDellaRfc7914() throws {
        XCTAssertEqual(esa(try Scrypt.deriva(password: Data(), sale: Data(), n: 16, r: 1, p: 1, lunghezza: 64)),
                       "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442"
                       + "fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906")
        XCTAssertEqual(esa(try Scrypt.deriva(password: Data("password".utf8), sale: Data("NaCl".utf8),
                                             n: 1024, r: 8, p: 16, lunghezza: 64)),
                       "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b373162"
                       + "2eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640")
        XCTAssertEqual(esa(try Scrypt.deriva(password: Data("pleaseletmein".utf8), sale: Data("SodiumChloride".utf8),
                                             n: 16384, r: 8, p: 1, lunghezza: 64)),
                       "7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2"
                       + "d5432955613f0fcf62d49705242a9af9e61e85dc0d651e40dfcf017b45575887")
    }

    func testComeIlPcConIParametriDelForziere() throws {
        let inizio = Date()
        let chiave = try Scrypt.deriva(password: Data("tre parole".utf8), sale: Data(0..<16),
                                       n: 1 << 17, r: 8, p: 1, lunghezza: 32)
        XCTAssertEqual(esa(chiave), "76cbd82316ab0168f1f6114a6f6070746e1ab22c6bb117d82f29fc25292bce6d")
        let a = XCTAttachment(string: "scrypt n=2^17: \(Date().timeIntervalSince(inizio)) s")
        a.lifetime = .keepAlways
        add(a)
        print("scrypt n=2^17:", Date().timeIntervalSince(inizio), "s")
    }

    func testParametriStraniSiFermano() {
        XCTAssertThrowsError(try Scrypt.deriva(password: Data(), sale: Data(), n: 15, r: 1, p: 1, lunghezza: 32))
        XCTAssertThrowsError(try Scrypt.deriva(password: Data(), sale: Data(), n: 16, r: 0, p: 1, lunghezza: 32))
    }
}
