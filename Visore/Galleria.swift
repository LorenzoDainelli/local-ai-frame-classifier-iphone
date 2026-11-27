import ImageIO
import SwiftUI
import UIKit
import VisoreKit

final class Miniature {
    static let tutte = Miniature()
    static let scalini: [CGFloat] = [96, 200, 400, 640, 1400]
    private let cache = NSCache<NSString, UIImage>()

    init() { cache.totalCostLimit = 160 * 1024 * 1024 }

    func sfuma() { cache.removeAllObjects() }

    static func scalino(_ lato: CGFloat) -> CGFloat {
        scalini.first { $0 >= lato } ?? scalini[scalini.count - 1]
    }

    private func chiave(_ posto: String, _ scalino: CGFloat) -> NSString {
        "\(posto)#\(Int(scalino))" as NSString
    }

    func pronta(_ posto: String) -> UIImage? {
        for b in Miniature.scalini.reversed() {
            if let fatta = cache.object(forKey: chiave(posto, b)) { return fatta }
        }
        return nil
    }

    func pronta(_ posto: String, lato: CGFloat) -> UIImage? {
        let serve = Miniature.scalino(lato)
        for b in Miniature.scalini where b >= serve {
            if let fatta = cache.object(forKey: chiave(posto, b)) { return fatta }
        }
        return nil
    }

    func carica(_ pacchetto: Pacchetto, _ posto: String, lato: CGFloat) async -> UIImage? {
        if let fatta = pronta(posto, lato: lato) { return fatta }
        let scalino = Miniature.scalino(lato)
        let immagine = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let dati = try? pacchetto.apri(posto),
                  let fonte = CGImageSourceCreateWithData(dati as CFData, nil) else { return nil }
            let opzioni: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: scalino,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(fonte, 0, opzioni as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }.value
        if let immagine {
            cache.setObject(immagine, forKey: chiave(posto, scalino),
                            cost: Int(immagine.size.width * immagine.size.height * immagine.scale * immagine.scale * 4))
        }
        return immagine
    }
}

struct GruppoDelGiorno: Identifiable {
    let giorno: String?
    var scatti: [Scatto]
    var per = 10
    var id: String { "\(per)-" + (giorno ?? "senza-data") }
}

enum Testi {
    static let lettura: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func giorno(_ testo: String?) -> String {
        guard let testo, let data = lettura.date(from: testo) else { return "Senza data" }
        let anno = Calendar.current.component(.year, from: data)
        let questo = Calendar.current.component(.year, from: Date())
        var stile = Date.FormatStyle().day().month(.wide).locale(Locale(identifier: "it_IT"))
        if anno != questo { stile = stile.year() }
        if Calendar.current.isDateInToday(data) { return "Oggi" }
        if Calendar.current.isDateInYesterday(data) { return "Ieri" }
        return data.formatted(stile)
    }

    static func mese(_ testo: String) -> String {
        guard let data = lettura.date(from: testo) else { return testo }
        return data.formatted(Date.FormatStyle().month(.wide).year().locale(Locale(identifier: "it_IT")))
            .capitalized(with: Locale(identifier: "it_IT"))
    }

    static let mesiCorti = ["Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic"]

    static func tempo(_ chiave: String?, _ per: Int) -> String {
        guard let chiave else { return "Senza data" }
        let anno = String(chiave.prefix(4))
        guard per > 4, chiave.count >= 7, let m = Int(chiave.dropFirst(5).prefix(2)), (1...12).contains(m) else {
            return anno
        }
        return "\(mesiCorti[m - 1]) \(anno)"
    }

    private static func pezzi(_ testo: String) -> (anno: Int, mese: Int?, giorno: Int?)? {
        let parti = testo.prefix(10).split(separator: "-")
        guard let primo = parti.first, let anno = Int(primo) else { return nil }
        var mese: Int?
        if parti.count > 1, let m = Int(parti[1]), (1...12).contains(m) { mese = m }
        var giorno: Int?
        if mese != nil, parti.count > 2, let g = Int(parti[2]), (1...31).contains(g) { giorno = g }
        return (anno, mese, giorno)
    }

    static func arco(_ dal: String?, _ al: String?, _ per: Int) -> String {
        guard let primo = dal ?? al, let ultimo = al ?? dal,
              let a = pezzi(primo), let b = pezzi(ultimo) else { return "Senza data" }
        guard per > 4, let m1 = a.mese, let m2 = b.mese else {
            return a.anno == b.anno ? "\(a.anno)" : "\(a.anno)–\(b.anno)"
        }
        let n1 = mesiCorti[m1 - 1]
        let n2 = mesiCorti[m2 - 1]
        guard per > 7, let g1 = a.giorno, let g2 = b.giorno else {
            if a.anno != b.anno { return "\(n1) \(a.anno) – \(n2) \(b.anno)" }
            return m1 == m2 ? "\(n2) \(b.anno)" : "\(n1)–\(n2) \(b.anno)"
        }
        if a.anno != b.anno { return "\(g1) \(n1) \(a.anno) – \(g2) \(n2) \(b.anno)" }
        if m1 != m2 { return "\(g1) \(n1) – \(g2) \(n2) \(b.anno)" }
        return g1 == g2 ? "\(g2) \(n2) \(b.anno)" : "\(g1)–\(g2) \(n2) \(b.anno)"
    }

    static func numero(_ n: Int) -> String {
        n.formatted(.number.locale(Locale(identifier: "it_IT")))
    }

    static func foto(_ n: Int) -> String {
        n == 1 ? "1 foto" : "\(numero(n)) foto"
    }

    static func periodo(_ dal: String?, _ al: String?) -> String? {
        let a = dal.map { String($0.prefix(4)) }
        let b = al.map { String($0.prefix(4)) }
        switch (a, b) {
        case let (a?, b?): return a == b ? a : "\(a)–\(b)"
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    static func istante(_ testo: String) -> String {
        guard let data = ISO8601DateFormatter().date(from: testo) else { return testo }
        return data.formatted(Date.FormatStyle(date: .long, time: .shortened).locale(Locale(identifier: "it_IT")))
    }

    static func ora(_ testo: String?) -> String? {
        guard let testo, testo.count >= 16 else { return nil }
        let i = testo.index(testo.startIndex, offsetBy: 11)
        let ora = String(testo[i..<testo.index(i, offsetBy: 5)])
        return ora.count == 5 && ora.dropFirst(2).hasPrefix(":") ? ora : nil
    }

    static func luoghi(_ nomi: [String]) -> String? {
        switch nomi.count {
        case 0: return nil
        case 1, 2: return nomi.joined(separator: " · ")
        default: return nomi.prefix(2).joined(separator: " · ") + " e altri \(nomi.count - 2)"
        }
    }

    static func durata(_ ms: Int?) -> String {
        let s = max(0, (ms ?? 0) / 1000)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }
}

@MainActor
final class Elenco: ObservableObject {
    @Published private(set) var scatti: [Scatto] = []
    @Published private(set) var finiti = false
    let pagina = 600
    let giorni: [Giorno]
    let perGiorno: [String: Giorno]
    private let prendi: (Int, Int) -> [Scatto]

    init(archivio: Archivio, filtro: Filtro) {
        prendi = { quanti, dopo in (try? archivio.scatti(filtro: filtro, limite: quanti, dopo: dopo)) ?? [] }
        let giorni = (try? archivio.giorni(filtro: filtro)) ?? []
        self.giorni = giorni
        perGiorno = Dictionary(giorni.compactMap { g in g.giorno.map { ($0, g) } }, uniquingKeysWith: { a, _ in a })
        altri()
    }

    var totale: Int { giorni.reduce(0) { $0 + $1.quanti } }

    func altri() {
        guard !finiti else { return }
        let nuovi = prendi(pagina, scatti.count)
        finiti = nuovi.count < pagina
        scatti += nuovi
    }

    func almeno(_ quanti: Int) {
        let mancano = quanti - scatti.count
        guard !finiti, mancano > 0 else { return }
        let nuovi = prendi(mancano, scatti.count)
        finiti = nuovi.count < mancano
        scatti += nuovi
    }

    var linea: Linea { Linea(giorni.compactMap { g in g.giorno.map { ($0, g.quanti) } }) }
}

struct Linea {
    let giorni: [String]
    let prima: [Int]
    let totale: Int

    init(_ tappe: [(String, Int)]) {
        var giorni: [String] = []
        var prima: [Int] = []
        var somma = 0
        for (g, n) in tappe where n > 0 {
            giorni.append(g)
            prima.append(somma)
            somma += n
        }
        self.giorni = giorni
        self.prima = prima
        totale = somma
    }

    func indice(a frazione: CGFloat) -> Int? {
        guard totale > 0 else { return nil }
        let quanti = Int(min(0.9999, max(0, frazione)) * CGFloat(totale))
        var basso = 0
        var alto = prima.count - 1
        while basso < alto {
            let mezzo = (basso + alto + 1) / 2
            if prima[mezzo] <= quanti { basso = mezzo } else { alto = mezzo - 1 }
        }
        return basso
    }

    struct Anno: Hashable {
        let anno: String
        let frazione: CGFloat
    }

    var anni: [Anno] {
        var uscita: [Anno] = []
        for (i, g) in giorni.enumerated() {
            let anno = String(g.prefix(4))
            if uscita.last?.anno != anno {
                uscita.append(Anno(anno: anno, frazione: CGFloat(prima[i]) / CGFloat(max(1, totale))))
            }
        }
        return uscita
    }
}

struct GrigliaGiorni: View {
    let pacchetto: Pacchetto
    let titolo: String
    let sottotitolo: String?
    let radice: Bool
    let cima: Int
    let testa: AnyView?
    let menu: AnyView?
    let vuota: String
    let raccolta: Int64?
    let conIndietro: Bool
    @EnvironmentObject var cassetto: Cassetto
    @EnvironmentObject var interfaccia: Interfaccia
    @EnvironmentObject var annunci: Annunci
    @Environment(\.dismiss) private var indietro
    @Environment(\.vaiA) private var vaiA
    @StateObject private var elenco: Elenco
    @State private var scelti: Set<Int64>?
    @State private var chiedeTogli = false
    @AppStorage("visore.livello") private var livello = 1
    @AppStorage("visore.proporzioni") private var proporzioni = false
    @State private var visto: Int64 = 0
    @State private var timone = Timone()
    @State private var etichetta: String?
    @State private var giu = true
    @State private var anteprima: Scatto?
    @State private var compatta = false
    @State private var anno: String?
    @State private var altoTesta: CGFloat = 0
    @State private var dal: String?
    @State private var al: String?
    @State private var conPeriodo = false

    static let livelli = GrigliaController.livelli
    static let prefissi = GrigliaController.prefissi

    init(pacchetto: Pacchetto, filtro: Filtro = Filtro(), titolo: String, sottotitolo: String? = nil,
         radice: Bool = false, cima: Int = 0, testa: AnyView? = nil, menu: AnyView? = nil,
         raccolta: Int64? = nil, vuota: String = "Qui non ci sono foto.", conIndietro: Bool = true) {
        self.conIndietro = conIndietro
        self.pacchetto = pacchetto
        self.titolo = titolo
        self.sottotitolo = sottotitolo
        self.radice = radice
        self.cima = cima
        self.testa = testa
        self.menu = menu
        self.raccolta = raccolta
        self.vuota = vuota
        _elenco = StateObject(wrappedValue: Elenco(archivio: pacchetto.archivio, filtro: filtro))
    }

    var body: some View {
        let i = min(max(livello, 0), GrigliaGiorni.livelli.count - 1)
        let per = GrigliaGiorni.prefissi[i]
        let linea = elenco.linea
        ZStack {
            GrigliaNativa(pacchetto: pacchetto, scatti: elenco.scatti, finiti: elenco.finiti,
                          perGiorno: elenco.perGiorno, livello: i, proporzioni: proporzioni,
                          cuori: cassetto.cuori, scelti: scelti, visto: visto,
                          cima: comeIPhone ? AnyView(vuotoIPhone) : AnyView(sopra(linea)),
                          fondo: scelti == nil ? 100 : 160, timone: timone, azioni: azioniGriglia(linea),
                          rovescio: comeIPhone, sottoTesta: comeIPhone ? altoTesta : 0)
                .ignoresSafeArea(.container, edges: .vertical)
        }
        .overlay(alignment: .top) {
            if comeIPhone { testaIPhone(linea, per) }
        }
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                if !comeIPhone, per < 10, compatta, let etichetta {
                    EtichettaTempo(testo: Testi.tempo(etichetta, per), giu: giu)
                        .padding(.top, 54)
                        .padding(.leading, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
                }
            }
            .animation(Moto.passo, value: !comeIPhone && per < 10 && compatta && etichetta != nil)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .trailing) {
            BarraAnni(linea: linea, rovescio: comeIPhone) { vai($0, linea) }
                .padding(.top, comeIPhone ? altoTesta + 8 : 120)
        }
        .onChange(of: cima) { _, _ in
            timone.inCima()
            anno = nil
        }
        .testaCompatta(titolo, visibile: compatta && !comeIPhone, indietro: torna) { azioni }
        .background(Tinta.fondo.ignoresSafeArea())
        .senzaBarraDiSistema()
        .overlay {
            if let anteprima {
                Anteprima(pacchetto: pacchetto, scatto: anteprima)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(duration: 0.25), value: anteprima?.id)
        .sensoryFeedback(.impact(weight: .medium), trigger: anteprima?.id) { _, nuovo in nuovo != nil }
        .safeAreaInset(edge: .bottom) {
            if let scelti {
                BarraScelta(quante: scelti.count, tuttiColCuore: tuttiColCuore, raccolta: raccolta,
                            impronte: { impronteScelte }, cuore: { acceso in
                                let n = impronteScelte.count
                                if cassetto.cuore(impronteScelte, acceso: acceso) {
                                    annunci.di(acceso ? "Cuore a \(Testi.foto(n))" : "Cuore tolto a \(Testi.foto(n))",
                                               simbolo: acceso ? "heart.fill" : "heart.slash")
                                    finito()
                                }
                            }, togli: { chiedeTogli = true }, finito: finito)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .confirmationDialog("Togliere dalla raccolta?", isPresented: $chiedeTogli, titleVisibility: .visible) {
            Button(impronteScelte.count == 1 ? "Togli 1 foto" : "Togli \(Testi.numero(impronteScelte.count)) foto",
                   role: .destructive) {
                if let raccolta, cassetto.togli(impronteScelte, da: raccolta) {
                    annunci.di("Tolte dalla raccolta", simbolo: "rectangle.stack.badge.minus")
                    finito()
                }
            }
        } message: {
            Text("Le foto restano nell'archivio: escono solo da questa raccolta.")
        }
        .onChange(of: scelti == nil) { _, nessuno in interfaccia.scegliendo = !nessuno }
        .onDisappear { if scelti != nil { scelti = nil; interfaccia.scegliendo = false } }
    }

    private var comeIPhone: Bool { Griglia.comeIPhone && radice }

    @ViewBuilder
    private var vuotoIPhone: some View {
        if elenco.scatti.isEmpty {
            Vuoto(titolo: "Nessuna foto", testo: vuota)
        }
    }

    private func testaIPhone(_ linea: Linea, _ per: Int) -> some View {
        TestaFoto(titolo: titolo, data: conPeriodo && !elenco.scatti.isEmpty ? Testi.arco(dal, al, per) : nil,
                  conteggio: sottotitoloVero, nascosto: compatta) {
            azioni
        } sotto: {
            pillole(linea)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { nuovo in
            if abs(nuovo - altoTesta) > 0.5 { altoTesta = nuovo }
        }
    }

    private func sopra(_ linea: Linea) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Testa(titolo: titolo, sottotitolo: sottotitoloVero, indietro: torna) { azioni }
            if radice { pillole(linea) }
            if let testa { testa }
            if elenco.scatti.isEmpty {
                Vuoto(titolo: "Nessuna foto", testo: vuota)
            }
        }
        .environmentObject(cassetto)
        .environmentObject(interfaccia)
        .environmentObject(annunci)
        .environment(\.vaiA, vaiA)
        .tint(Tinta.accento)
    }

    private func azioniGriglia(_ linea: Linea) -> AzioniGriglia {
        AzioniGriglia(
            livello: { livello = $0 },
            compatta: { if compatta != $0 { compatta = $0 } },
            etichetta: { chiave, verso in
                giu = verso
                withAnimation(.spring(duration: 0.38, bounce: 0.16)) { etichetta = chiave }
            },
            altri: { elenco.altri() },
            cambia: { cambia($0) },
            tenuto: { anteprima = $0 },
            apri: { i in
                guard elenco.scatti.indices.contains(i) else { return nil }
                visto = elenco.scatti[i].id
                return AnyView(FotoAperta(pacchetto: pacchetto, elenco: elenco, inizio: i, visto: $visto,
                                          raccolta: raccolta, rovescio: comeIPhone)
                    .environmentObject(cassetto)
                    .environmentObject(annunci)
                    .environmentObject(interfaccia)
                    .tint(Tinta.accento))
            },
            aperto: { cassetto.aperta = $0 },
            intestazione: { gruppo in
                if gruppo.per == 10 {
                    return AnyView(Intestazione(giorno: gruppo.giorno, luoghi: luoghi(gruppo), quante: quanteDel(gruppo),
                                                tutte: scelti == nil ? nil : tutteDelGiorno(gruppo, linea)))
                }
                return AnyView(IntestazioneBreve(testo: Testi.tempo(gruppo.giorno, gruppo.per), grande: gruppo.per == 4))
            },
            periodo: { a, b in
                if dal != a { dal = a }
                if al != b { al = b }
                if !conPeriodo { conPeriodo = true }
            })
    }

    private var torna: (() -> Void)? {
        if radice || !conIndietro { return nil }
        return { indietro() }
    }

    private var sottotitoloVero: String? {
        if let sottotitolo { return sottotitolo }
        guard radice else { return nil }
        let n = elenco.totale
        return n == 1 ? "1 foto o video" : "\(Testi.numero(n)) foto e video"
    }

    @ViewBuilder
    private var azioni: some View {
        HStack(spacing: 8) {
            if !elenco.scatti.isEmpty {
                Button {
                    withAnimation(.snappy) { scelti = scelti == nil ? [] : nil }
                } label: {
                    Pillola(testo: scelti == nil ? "Scegli" : "Annulla", scelta: scelti != nil)
                }
                .buttonStyle(Premuto())
            }
            if let menu { menu }
            if radice { AzioniDiTesta() }
        }
    }

    private func pillole(_ linea: Linea) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                Collegamento(TutteLeRaccolte()) {
                    Pillola(testo: "Raccolte", simbolo: "heart")
                }
                .buttonStyle(Premuto())
                Rectangle().fill(Tinta.linea).frame(width: 0.5, height: 20).padding(.horizontal, 4)
                Button {
                    anno = nil
                    timone.inCima()
                } label: { Pillola(testo: "Tutte", scelta: anno == nil) }
                .buttonStyle(Premuto())
                ForEach(linea.anni, id: \.anno) { a in
                    Button {
                        anno = a.anno
                        if let i = linea.giorni.firstIndex(where: { $0.hasPrefix(a.anno) }) { vai(i, linea) }
                    } label: { Pillola(testo: a.anno, scelta: anno == a.anno) }
                    .buttonStyle(Premuto())
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 4)
    }

    private func quanteDel(_ gruppo: GruppoDelGiorno) -> Int {
        gruppo.giorno.flatMap { elenco.perGiorno[$0]?.quanti } ?? gruppo.scatti.count
    }

    private var impronteScelte: [String] {
        guard let scelti else { return [] }
        return elenco.scatti.filter { scelti.contains($0.id) }.map(\.impronta)
    }

    private var tuttiColCuore: Bool {
        let i = impronteScelte
        return !i.isEmpty && i.allSatisfy { cassetto.cuori.contains($0) }
    }

    private func finito() {
        withAnimation(.snappy) { scelti = nil }
    }

    private func cambia(_ id: Int64) {
        guard var s = scelti else { return }
        if s.contains(id) { s.remove(id) } else { s.insert(id) }
        scelti = s
    }

    private func tutteDelGiorno(_ gruppo: GruppoDelGiorno, _ linea: Linea) -> (Bool, () -> Void) {
        let ids = Set(gruppo.scatti.map(\.id))
        let completo = gruppo.giorno.flatMap { elenco.perGiorno[$0] }.map { $0.quanti <= ids.count } ?? true
        let tutte = completo && ids.isSubset(of: scelti ?? [])
        return (tutte, {
            guard var s = scelti else { return }
            if tutte {
                s.subtract(ids)
            } else {
                if let g = gruppo.giorno, let i = linea.giorni.firstIndex(of: g) {
                    elenco.almeno(linea.prima[i] + (elenco.perGiorno[g]?.quanti ?? 0))
                }
                for x in elenco.scatti where x.giorno == gruppo.giorno { s.insert(x.id) }
            }
            scelti = s
        })
    }

    private func vai(_ i: Int, _ linea: Linea) {
        guard linea.giorni.indices.contains(i) else { return }
        let giorno = linea.giorni[i]
        elenco.almeno(linea.prima[i] + (elenco.perGiorno[giorno]?.quanti ?? 1))
        timone.vai(giorno)
    }

    private func luoghi(_ gruppo: GruppoDelGiorno) -> [String] {
        if let g = gruppo.giorno, let r = elenco.perGiorno[g] { return r.luoghi }
        var visti: [String: Int] = [:]
        for s in gruppo.scatti { if let l = s.luogo { visti[l, default: 0] += 1 } }
        return visti.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }
}

struct EtichettaTempo: View {
    let testo: String
    let giu: Bool

    var body: some View {
        ZStack {
            Text(testo)
                .font(Carattere.serif(17, .headline))
                .foregroundStyle(Tinta.ink)
                .monospacedDigit()
                .fixedSize()
                .id(testo)
                .transition(.push(from: giu ? .bottom : .top))
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .clipShape(Capsule())
        .vetro(Capsule(), ripiego: .regularMaterial, ombra: true)
    }
}

struct IntestazioneBreve: View {
    let testo: String
    let grande: Bool

    var body: some View {
        Text(testo)
            .font(grande ? Carattere.titoletto : Carattere.giorno)
            .foregroundStyle(Tinta.ink)
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.top, grande ? 16 : 12)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BarraAnni: View {
    let linea: Linea
    var rovescio = false
    let vai: (Int) -> Void
    @State private var dito: CGFloat?
    @State private var ultimo: Int?
    @State private var mese: String?

    var body: some View {
        GeometryReader { g in
            let alto = max(1, g.size.height)
            ZStack(alignment: .topTrailing) {
                Color.clear.contentShape(Rectangle())
                if let dito {
                    let anni = linea.anni
                    ForEach(anni, id: \.anno) { a in
                        Text(a.anno)
                            .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Tinta.tenue)
                            .fixedSize()
                            .offset(x: -30, y: min(alto - 14, posto(a, anni) * alto))
                    }
                    if let i = linea.indice(a: frazione(dito / alto)), linea.giorni.indices.contains(i) {
                        Text(Testi.mese(linea.giorni[i]))
                            .font(Carattere.piccolo)
                            .foregroundStyle(Tinta.ink)
                            .fixedSize()
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Tinta.superficie, in: Capsule())
                            .overlay(Capsule().stroke(Tinta.lineaForte, lineWidth: 0.5))
                            .shadow(color: Tinta.ombra, radius: 10, y: 4)
                            .offset(x: -72, y: min(max(0, dito - 16), alto - 32))
                    }
                    Capsule().fill(Tinta.accento)
                        .frame(width: 5, height: 36)
                        .offset(x: -4, y: min(max(0, dito - 18), alto - 36))
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    guard linea.totale > 0 else { return }
                    dito = min(alto, max(0, v.location.y))
                    if let i = linea.indice(a: frazione(v.location.y / alto)), i != ultimo {
                        ultimo = i
                        mese = String(linea.giorni[i].prefix(7))
                        vai(i)
                    }
                }
                .onEnded { _ in
                    dito = nil
                    ultimo = nil
                    mese = nil
                })
            .sensoryFeedback(.selection, trigger: mese)
        }
        .frame(width: 26)
        .animation(.easeOut(duration: 0.15), value: dito == nil)
    }

    private func frazione(_ f: CGFloat) -> CGFloat {
        rovescio ? 1 - f : f
    }

    private func posto(_ a: Linea.Anno, _ anni: [Linea.Anno]) -> CGFloat {
        guard rovescio, let i = anni.firstIndex(of: a) else { return a.frazione }
        return 1 - (i + 1 < anni.count ? anni[i + 1].frazione : 1)
    }
}

struct TestaFoto<Azioni: View, Sotto: View>: View {
    let titolo: String
    let data: String?
    let conteggio: String?
    let nascosto: Bool
    @ViewBuilder var azioni: () -> Azioni
    @ViewBuilder var sotto: () -> Sotto
    @State private var altoCima: CGFloat = 0
    @State private var altoTutto: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(titolo)
                        .font(Carattere.titolo)
                        .foregroundStyle(Tinta.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(data ?? " ")
                        .font(Carattere.piccolo)
                        .foregroundStyle(Tinta.attenuato)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText())
                        .animation(Moto.passo, value: data)
                        .accessibilityIdentifier("periodo")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
                azioni()
                    .fixedSize()
                    .layoutPriority(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { altoCima = $0 }
            VStack(alignment: .leading, spacing: 6) {
                if let conteggio {
                    Text(conteggio)
                        .font(Carattere.minore)
                        .foregroundStyle(Tinta.tenue)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                }
                sotto()
            }
            .opacity(nascosto ? 0 : 1)
            .blur(radius: nascosto ? 6 : 0)
            .offset(y: nascosto ? -10 : 0)
            .allowsHitTesting(!nascosto)
            .accessibilityHidden(nascosto)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { altoTutto = $0 }
        .background(alignment: .top) {
            SfumaturaTesta(sotto: nascosto ? 28 - max(0, altoTutto - altoCima) : 28)
        }
        .animation(Moto.scena, value: nascosto)
    }
}

struct Intestazione: View {
    let giorno: String?
    let luoghi: [String]
    var quante: Int? = nil
    var tutte: (Bool, () -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Testi.giorno(giorno)).font(Carattere.giorno).foregroundStyle(Tinta.ink)
                if let l = Testi.luoghi(luoghi) {
                    Text(l).font(Carattere.minore).foregroundStyle(Tinta.tenue).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let tutte {
                Button(tutte.0 ? "Nessuna" : "Tutte", action: tutte.1)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tinta.accento)
            } else if let quante {
                Text(Testi.foto(quante)).font(.system(size: 12)).foregroundStyle(Tinta.tenue).monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Luccichio: View {
    @State private var acceso = false

    var body: some View {
        Rectangle()
            .fill(acceso ? Tinta.superficieAlta : Tinta.pozzo)
            .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { acceso = true } }
    }
}

struct Anteprima: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    @State private var immagine: UIImage?
    @State private var originale = false
    @StateObject private var movimento = Movimento()

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            if let immagine {
                Image(uiImage: immagine)
                    .resizable()
                    .allowedDynamicRange(originale ? .high : .standard)
                    .scaledToFit()
                    .overlay {
                        if scatto.live || scatto.video {
                            StratoVideo(lettore: movimento.lettore)
                                .opacity(movimento.inCorso ? 1 : 0)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
                    .padding(24)
            }
        }
        .allowsHitTesting(false)
        .onDisappear { movimento.chiudi() }
        .task(id: scatto.id) {
            let mini = scatto.mini ?? scatto.posto
            immagine = Miniature.tutte.pronta(mini)
            if scatto.video {
                if immagine == nil { immagine = await Miniature.tutte.carica(pacchetto, mini, lato: 600) }
                await movimento.prepara(pacchetto: pacchetto, posto: scatto.posto)
            } else {
                if let grande = await Originali.tutti.carica(pacchetto, scatto.posto) {
                    immagine = grande
                    originale = true
                } else if immagine == nil {
                    immagine = await Miniature.tutte.carica(pacchetto, mini, lato: 600)
                }
                if scatto.live, let m = scatto.postoMovimento {
                    await movimento.prepara(pacchetto: pacchetto, posto: m)
                }
            }
            if !Task.isCancelled, movimento.pronto { movimento.inAnello() }
        }
    }
}

struct VoceImpostazione: View {
    let nome: String
    let valore: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(nome).font(.system(size: 15)).foregroundStyle(Tinta.tenue)
            Spacer(minLength: 8)
            Text(valore).font(.system(size: 15, weight: .medium)).foregroundStyle(Tinta.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 11)
    }
}

struct GruppoImpostazioni<Dentro: View>: View {
    let titolo: String
    var nota: String? = nil
    @ViewBuilder var dentro: () -> Dentro

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo.uppercased()).etichettaMaiuscola().padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0) { dentro() }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tinta.fondo, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tinta.linea, lineWidth: 0.5))
            if let nota {
                Text(nota).font(.system(size: 12.5)).foregroundStyle(Tinta.tenue).padding(.horizontal, 4)
            }
        }
    }
}

struct Spiegazione: View {
    let testo: String

    var body: some View {
        Text(testo).font(.system(size: 14.5)).foregroundStyle(Tinta.attenuato)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 11)
    }
}

struct Impostazioni: View {
    let pacchetto: Pacchetto
    @AppStorage("visore.proporzioni") private var proporzioni = false
    @EnvironmentObject var cassetto: Cassetto
    @Environment(\.dismiss) private var chiudi
    @Environment(\.accessibilityReduceMotion) private var piano
    @AppStorage(Giro.chiave) private var giroVisto = false
    @AppStorage(Vetro.chiave) private var vetro = true
    @StateObject private var avvisi = Annunci()
    @State private var quanti: Int
    @State private var tremaVetro = 0
    @State private var apparso = false

    init(pacchetto: Pacchetto) {
        self.pacchetto = pacchetto
        _quanti = State(initialValue: (try? pacchetto.archivio.quanti()) ?? 0)
    }

    private var notaVetro: String {
        if !Vetro.vero(true) {
            return UIAccessibility.isReduceTransparencyEnabled
                ? "Spento perché su iPhone è attivo «Riduci trasparenza» (Accessibilità)."
                : "Il vetro liquido arriva con iOS 26."
        }
        return "Acceso: tasti e barre di vetro che lascia vedere le foto sotto, come su iPhone. "
            + "Spento: tasti pieni e barre opache."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TestaFoglio(titolo: "Impostazioni", sotto: "Come si vede e come si protegge il Visore.") { chiudi() }
                TitolettoFoglio(testo: "Aspetto")
                HStack(spacing: 8) {
                    TesseraTipo(nome: "Vetro liquido", simbolo: "drop.halffull", quanti: nil,
                                acceso: vetro && Vetro.vero(true), trema: tremaVetro,
                                stato: !Vetro.vero(true) ? "Non c'è" : vetro ? "Acceso" : "Spento") { cambiaVetro() }
                        .opacity(Vetro.vero(true) ? 1 : 0.55)
                        .entra(apparso, 0, piano)
                    TesseraTipo(nome: "Proporzioni vere", simbolo: "rectangle.grid.3x2", quanti: nil,
                                acceso: proporzioni, trema: 0,
                                stato: proporzioni ? "Accese" : "Spente") { proporzioni.toggle() }
                        .entra(apparso, 1, piano)
                }
                NotaFoglio(testo: notaVetro)
                    .contentTransition(.opacity)
                    .animation(Moto.passo, value: vetro)
                NotaFoglio(testo: "Spento: miniature quadrate, piene. Acceso: ogni foto con la sua forma, dentro il suo quadrato. "
                           + "Pizzica la griglia: 1, 3, 5, 15 o 31 foto per riga. A 15 si vedono i mesi, a 31 gli anni.")
                gruppo("Firma", 2) {
                    if let scade = Firma.scadenza() {
                        Text(Firma.aParole(fino: scade)).font(Carattere.piccolo).foregroundStyle(Tinta.ink)
                            .padding(.top, 11)
                    }
                    Spiegazione(testo: "Si rinnova con AltStore, avviando AltServer sul portatile. Rinnovare non tocca niente. "
                                + "Cancellare l'app e rimetterla porta via il pacchetto: andrebbe ricopiato tutto dal PC.")
                }
                gruppo("Blocco", 3) {
                    Spiegazione(testo: "Il Visore si chiude appena esci o cambi app, e al rientro chiede Face ID. "
                                + "La password torna ogni 7 giorni, dopo un riavvio e dopo 5 Face ID falliti.")
                }
                gruppo("Riservatezza", 4) {
                    Spiegazione(testo: "Se lo schermo viene registrato o duplicato, il Visore si copre. Negli screenshot "
                                + "esce nero. È una difesa parziale: una seconda fotocamera la supera.")
                    Divider().overlay(Tinta.linea)
                    Spiegazione(testo: "Il Visore non usa internet, non manda notifiche e non accetta le tastiere di altre app. "
                                + "Chiede un solo permesso: la posizione mentre è aperto, per il diario.")
                    Divider().overlay(Tinta.linea)
                    if let dal = cassetto.diarioDal {
                        VoceImpostazione(nome: "Diario dal", valore: Testi.giorno(String(dal.prefix(10))))
                    } else {
                        VoceImpostazione(nome: "Diario", valore: "ancora vuoto")
                    }
                }
                gruppo("Foto aperta", 5) {
                    Spiegazione(testo: "Un tocco nasconde e rimostra tutto. Tieni premuto su una live photo: si muove finché tieni. "
                                + "Due tocchi mettono il cuore. In basso le miniature di prima e dopo: toccane una per saltarci. "
                                + "Giù di scatto chiude, su mostra le informazioni.")
                }
                gruppo("A caso", 6) {
                    Spiegazione(testo: "Il tasto arancio con le frecce, accanto all'ingranaggio, mescola foto, Live e video. "
                                + "Scegli tipo, nodi, persone e anni, poi guarda. Tocca a destra o a sinistra per andare "
                                + "avanti o indietro, al centro per nascondere i comandi. Tieni premuto per fermare, "
                                + "due tocchi mettono il cuore, giù chiude.")
                }
                gruppo("Pacchetto", 7) {
                    let info = pacchetto.archivio.informazioni()
                    VoceImpostazione(nome: "Foto e video", valore: Testi.numero(quanti))
                    if let fatto = info["fatto_il"] { VoceImpostazione(nome: "Fatto il", valore: Testi.istante(fatto)) }
                    if let n = info["nuove_ultimo_travaso"], let quante = Int(n), quante > 0 {
                        VoceImpostazione(nome: "Nuove nell'ultima copia", valore: Testi.numero(quante))
                    }
                    if let v = info["versione_officina"] { VoceImpostazione(nome: "Officina", valore: v) }
                    VoceImpostazione(nome: "Visore",
                                     valore: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
                gruppo("Licenze", 8) {
                    Spiegazione(testo: "SQLite: pubblico dominio. Crittografia: CryptoKit di Apple, compresa nel sistema. "
                                + "Carattere Source Serif 4: SIL Open Font License. "
                                + "Il resto del Visore è scritto per questo progetto e non usa librerie di altri.")
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { piede }
        .modifier(ConAnnunci(annunci: avvisi, sopra: 140))
        .sensoryFeedback(.selection, trigger: vetro)
        .sensoryFeedback(.selection, trigger: proporzioni)
        .sensoryFeedback(.warning, trigger: tremaVetro)
        .task { apparso = true }
    }

    private func gruppo<Dentro: View>(_ titolo: String, _ i: Int, @ViewBuilder _ dentro: () -> Dentro) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TitolettoFoglio(testo: titolo)
            VStack(alignment: .leading, spacing: 0) { dentro() }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cartaFoglio()
        }
        .entra(apparso, i, piano)
    }

    private var piede: some View {
        VStack(spacing: 9) {
            Conteggio(quanti: quanti, testo: quanti == 1 ? "scatto nel pacchetto" : "scatti nel pacchetto")
                .accessibilityElement(children: .combine)
            Button {
                chiudi()
                giroVisto = false
            } label: {
                Label("Rivedi il giro di benvenuto", systemImage: "sparkles")
            }
            .buttonStyle(TastoPieno())
            .shadow(color: Tinta.accento.opacity(0.32), radius: 12, y: 8)
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .piedeFoglio()
    }

    private func cambiaVetro() {
        guard Vetro.vero(true) else {
            tremaVetro += 1
            avvisi.di(UIAccessibility.isReduceTransparencyEnabled ? "Spento da «Riduci trasparenza»" : "Serve iOS 26",
                      simbolo: "exclamationmark.circle")
            return
        }
        withAnimation(Moto.scena) { vetro.toggle() }
    }
}

struct BarraScelta: View {
    let quante: Int
    let tuttiColCuore: Bool
    let raccolta: Int64?
    let impronte: () -> [String]
    let cuore: (Bool) -> Void
    let togli: () -> Void
    let finito: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button { cuore(!tuttiColCuore) } label: {
                Image(systemName: tuttiColCuore ? "heart.slash" : "heart")
                    .font(.system(size: 18)).frame(width: 44, height: 44).contentShape(Circle())
            }
            .buttonStyle(Premuto(quanto: 0.88))
            .accessibilityLabel(tuttiColCuore ? "Togli il cuore" : "Metti il cuore")
            Text(quante == 0 ? "Tocca le foto" : quante == 1 ? "1 scelta" : "\(Testi.numero(quante)) scelte")
                .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 110)
            if raccolta != nil {
                Button(role: .destructive, action: togli) {
                    Image(systemName: "rectangle.stack.badge.minus")
                        .font(.system(size: 17)).frame(width: 44, height: 44).contentShape(Circle())
                }
                .buttonStyle(Premuto(quanto: 0.88))
                .accessibilityLabel("Togli dalla raccolta")
            }
            MenuRaccolta(impronte: impronte, fatto: finito) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 17)).frame(width: 44, height: 44).contentShape(Circle())
            }
            .accessibilityLabel("Aggiungi a una raccolta")
        }
        .foregroundStyle(Tinta.ink)
        .disabled(quante == 0)
        .padding(5)
        .vetro(Capsule(), interattivo: true, ripiego: .regularMaterial, ombra: true)
        .animation(Moto.passo, value: quante)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
    }
}
