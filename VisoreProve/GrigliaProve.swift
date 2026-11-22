import XCTest

final class GrigliaProve: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-visore.prova", "YES", "-visore.giro.visto", "YES", "-visore.livello", "2",
                               "-visore.vetro", "YES", "-visore.scudo.saltato", "YES"]
    }

    private func scatta(_ nome: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = nome
        a.lifetime = .keepAlways
        add(a)
    }

    private func apri() -> XCUIElement {
        app.launch()
        let tasto = app.buttons["Apri"]
        XCTAssertTrue(tasto.waitForExistence(timeout: 30))
        scatta("0-sblocco")
        tasto.tap()
        let griglia = app.collectionViews.firstMatch
        XCTAssertTrue(griglia.waitForExistence(timeout: 240))
        sleep(2)
        return griglia
    }

    func testPizzicoEApertura() {
        let griglia = apri()
        scatta("1-cinque-per-riga")
        griglia.pinch(withScale: 0.45, velocity: -1.5)
        sleep(1)
        scatta("2-quindici-per-riga")
        griglia.pinch(withScale: 0.45, velocity: -1.5)
        sleep(1)
        scatta("3-trentuno-per-riga")
        griglia.pinch(withScale: 6, velocity: 3)
        sleep(1)
        scatta("4-ingrandita")
        griglia.pinch(withScale: 3, velocity: 2)
        sleep(1)
        scatta("5-una-per-riga")
        griglia.pinch(withScale: 0.3, velocity: -2)
        sleep(1)
        scatta("6-di-nuovo-piccola")
        let cella = griglia.cells.firstMatch
        XCTAssertTrue(cella.waitForExistence(timeout: 10))
        cella.tap()
        sleep(2)
        scatta("7-foto-aperta")
        let indietro = app.buttons["Indietro"].firstMatch
        if indietro.waitForExistence(timeout: 5) { indietro.tap() }
        sleep(2)
        scatta("8-foto-chiusa")
        XCTAssertTrue(griglia.exists)
    }

    func testRaccolteDallaPillola() {
        _ = apri()
        let raccolte = app.buttons["Raccolte"].firstMatch
        XCTAssertTrue(raccolte.waitForExistence(timeout: 10))
        raccolte.tap()
        sleep(2)
        scatta("9-raccolte")
        XCTAssertFalse(app.buttons["Raccolte"].firstMatch.isHittable && app.collectionViews.count > 0
                       && !app.staticTexts["Raccolte"].exists)
    }

    func testScegliEGiorno() {
        let griglia = apri()
        app.buttons["Scegli"].firstMatch.tap()
        sleep(1)
        griglia.cells.element(boundBy: 0).tap()
        sleep(1)
        scatta("10-scelta")
        app.buttons["Annulla"].firstMatch.tap()
        sleep(1)
        griglia.swipeUp()
        sleep(1)
        scatta("11-scorsa")
    }

    func testFotoApertaEUnaPerRiga() {
        if let k = app.launchArguments.firstIndex(of: "-visore.livello") { app.launchArguments[k + 1] = "0" }
        let griglia = apri()
        scatta("12-una-per-riga")
        griglia.pinch(withScale: 0.5, velocity: -1)
        sleep(1)
        scatta("13-tre-per-riga")
        griglia.cells.element(boundBy: 0).tap()
        sleep(3)
        scatta("14-foto-aperta")
        for n in 0..<4 {
            app.swipeLeft()
            sleep(2)
            scatta("15-foto-\(n)")
        }
    }
}
