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

    private func descrivi(_ nome: String) {
        let a = XCTAttachment(string: app.debugDescription)
        a.name = nome
        a.lifetime = .keepAlways
        add(a)
    }

    private func fotoAlCentro(_ griglia: XCUIElement) -> XCUIElement {
        let tutte = griglia.images.matching(NSPredicate(format: "label == 'Foto'"))
        let quadro = griglia.frame
        let centro = CGPoint(x: quadro.midX, y: quadro.minY + quadro.height * 0.55)
        var scelta = tutte.element(boundBy: 0)
        var meglio = CGFloat.greatestFiniteMagnitude
        for n in 0..<min(tutte.count, 60) {
            let una = tutte.element(boundBy: n)
            let f = una.frame
            guard f.width > 4, f.minY > quadro.minY + quadro.height * 0.25, f.maxY < quadro.maxY - 110 else { continue }
            let dx = f.midX - centro.x
            let dy = f.midY - centro.y
            let d = dx * dx + dy * dy
            if d < meglio {
                meglio = d
                scelta = una
            }
        }
        return scelta
    }

    private func periodo() -> XCUIElement {
        app.staticTexts["periodo"].firstMatch
    }

    private func controllaPeriodo(_ nome: String) {
        let data = periodo()
        XCTAssertTrue(data.waitForExistence(timeout: 10), "manca la data sotto il titolo (\(nome))")
        var piena = false
        for _ in 0..<10 where data.exists {
            if !data.label.trimmingCharacters(in: .whitespaces).isEmpty {
                piena = true
                break
            }
            sleep(1)
        }
        XCTAssertTrue(piena, "data vuota (\(nome))")
    }

    private func senzaIntestazioni(_ nome: String) {
        XCTAssertEqual(app.collectionViews.firstMatch.staticTexts.count, 0,
                       "nella griglia ci sono ancora intestazioni (\(nome))")
    }

    private func pilloleVisibili() -> Bool {
        let tasto = app.buttons["Raccolte"].firstMatch
        return tasto.exists && tasto.isHittable
    }

    private func togliAvvisi() {
        let trampolino = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for nome in ["Don’t Allow", "Don't Allow", "Non consentire"] {
            let tasto = trampolino.buttons[nome]
            if tasto.waitForExistence(timeout: 1) { tasto.tap() }
        }
    }

    private func apri() -> XCUIElement {
        app.launch()
        togliAvvisi()
        let tasto = app.buttons["Apri"]
        XCTAssertTrue(tasto.waitForExistence(timeout: 30))
        scatta("0-sblocco")
        tasto.tap()
        let griglia = app.collectionViews.firstMatch
        XCTAssertTrue(griglia.waitForExistence(timeout: 240))
        sleep(2)
        togliAvvisi()
        return griglia
    }

    func testPizzicoEApertura() {
        let griglia = apri()
        scatta("1-cinque-per-riga")
        controllaPeriodo("cinque")
        senzaIntestazioni("cinque")
        griglia.pinch(withScale: 0.45, velocity: -1.5)
        sleep(1)
        scatta("2-quindici-per-riga")
        controllaPeriodo("quindici")
        griglia.pinch(withScale: 0.45, velocity: -1.5)
        sleep(1)
        scatta("3-trentuno-per-riga")
        controllaPeriodo("trentuno")
        griglia.pinch(withScale: 6, velocity: 3)
        sleep(1)
        scatta("4-ingrandita")
        griglia.pinch(withScale: 3, velocity: 2)
        sleep(1)
        scatta("5-una-per-riga")
        griglia.pinch(withScale: 0.3, velocity: -2)
        sleep(1)
        scatta("6-di-nuovo-piccola")
        senzaIntestazioni("di nuovo piccola")
        let cella = fotoAlCentro(griglia)
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

    func testIndietroNeiNodi() {
        _ = apri()
        let sezione = app.buttons["Nodi"].firstMatch
        XCTAssertTrue(sezione.waitForExistence(timeout: 10))
        sezione.tap()
        sleep(1)
        let nodo = app.buttons.matching(identifier: "nodo").firstMatch
        XCTAssertTrue(nodo.waitForExistence(timeout: 10), "nella sezione Nodi non c'è nessun nodo")
        nodo.tap()
        sleep(2)
        scatta("10-dentro-un-nodo")
        let indietro = app.buttons["Indietro"].firstMatch
        XCTAssertTrue(indietro.waitForExistence(timeout: 10), "dentro un nodo manca il tasto indietro")
        indietro.tap()
        sleep(2)
        scatta("11-tornato-ai-nodi")
        XCTAssertTrue(app.buttons.matching(identifier: "nodo").firstMatch.waitForExistence(timeout: 5),
                      "il tasto indietro del nodo non torna all'elenco dei nodi")
        XCTAssertFalse(app.buttons["Indietro"].firstMatch.exists, "dopo indietro si è ancora dentro il nodo")
    }

    func testRaccolteDallaPillola() {
        _ = apri()
        let raccolte = app.buttons["Raccolte"].firstMatch
        XCTAssertTrue(raccolte.waitForExistence(timeout: 10))
        XCTAssertTrue(raccolte.isHittable, "all'inizio le pillole devono essere visibili")
        raccolte.tap()
        sleep(2)
        scatta("9-raccolte")
        XCTAssertFalse(app.buttons["Raccolte"].firstMatch.isHittable && app.collectionViews.count > 0
                       && !app.staticTexts["Raccolte"].exists)
    }

    func testScegliEGiorno() {
        let griglia = apri()
        controllaPeriodo("scegli")
        app.buttons["Scegli"].firstMatch.tap()
        sleep(1)
        fotoAlCentro(griglia).tap()
        sleep(1)
        scatta("10-scelta")
        XCTAssertTrue(app.staticTexts["1 scelta"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Annulla"].firstMatch.tap()
        sleep(1)
        griglia.swipeDown()
        sleep(1)
        scatta("11-scorsa")
        senzaIntestazioni("scorsa")
        controllaPeriodo("scorsa")
    }

    func testFotoApertaEUnaPerRiga() {
        if let k = app.launchArguments.firstIndex(of: "-visore.livello") { app.launchArguments[k + 1] = "0" }
        let griglia = apri()
        scatta("12-una-per-riga")
        controllaPeriodo("una per riga")
        let inizio = periodo().label
        XCTAssertTrue(pilloleVisibili(), "all'inizio le pillole devono essere visibili")
        griglia.swipeDown()
        sleep(2)
        scatta("12b-indietro-nel-tempo")
        XCTAssertFalse(pilloleVisibili(), "scorrendo le pillole devono sparire")
        XCTAssertTrue(app.staticTexts["Foto"].firstMatch.exists, "il titolo resta sopra")
        controllaPeriodo("indietro nel tempo")
        let a = XCTAttachment(string: "prima: \(inizio) · dopo: \(periodo().label)")
        a.name = "date"
        a.lifetime = .keepAlways
        add(a)
        for _ in 0..<4 {
            griglia.swipeUp(velocity: .fast)
            sleep(1)
        }
        sleep(1)
        scatta("12c-di-nuovo-in-fondo")
        XCTAssertTrue(pilloleVisibili(), "tornati all'inizio le pillole devono tornare")
        griglia.pinch(withScale: 0.5, velocity: -1)
        sleep(1)
        scatta("13-tre-per-riga")
        let prima = fotoAlCentro(griglia)
        descrivi("gerarchia-prima-del-tocco")
        prima.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(3)
        scatta("14-foto-aperta")
        descrivi("gerarchia-foto-aperta")
        for n in 0..<4 {
            app.scrollViews.firstMatch.swipeLeft(velocity: .fast)
            sleep(2)
            scatta("15-foto-\(n)")
            if n == 0 { descrivi("gerarchia-dopo-scorsa") }
        }
        let striscia = app.scrollViews.element(boundBy: 1).images
        if striscia.count > 2 {
            striscia.element(boundBy: 2).tap()
            sleep(2)
            scatta("16-dalla-striscia")
            descrivi("gerarchia-dalla-striscia")
        }
    }
}
