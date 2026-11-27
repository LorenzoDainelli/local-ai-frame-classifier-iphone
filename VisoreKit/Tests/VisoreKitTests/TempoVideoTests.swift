import XCTest
@testable import VisoreKit

final class TempoVideoTests: XCTestCase {

    func testIlTempoPassatoHaICentesimi() {
        XCTAssertEqual(TempoVideo.passato(3.45), "00:03,45")
        XCTAssertEqual(TempoVideo.passato(0), "00:00,00")
        XCTAssertEqual(TempoVideo.passato(0.29), "00:00,29")
        XCTAssertEqual(TempoVideo.passato(75.999), "01:15,99")
        XCTAssertEqual(TempoVideo.passato(-1), "00:00,00")
        XCTAssertEqual(TempoVideo.passato(.nan), "00:00,00")
    }

    func testIlTempoCheMancaEArrotondatoInSu() {
        XCTAssertEqual(TempoVideo.manca(8.30 - 3.45), "00:05")
        XCTAssertEqual(TempoVideo.manca(5), "00:05")
        XCTAssertEqual(TempoVideo.manca(5.01), "00:06")
        XCTAssertEqual(TempoVideo.manca(0.2), "00:01")
        XCTAssertEqual(TempoVideo.manca(0), "00:00")
        XCTAssertEqual(TempoVideo.manca(61), "01:01")
        XCTAssertEqual(TempoVideo.manca(-3), "00:00")
        XCTAssertEqual(TempoVideo.manca(.infinity), "00:00")
    }
}
