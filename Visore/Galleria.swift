import ImageIO
import SwiftUI
import UIKit
import VisoreKit

final class Miniature {
    static let tutte = Miniature()
    private let cache = NSCache<NSString, UIImage>()

    init() { cache.totalCostLimit = 120 * 1024 * 1024 }

    func sfuma() { cache.removeAllObjects() }

    func pronta(_ posto: String) -> UIImage? { cache.object(forKey: posto as NSString) }

    func carica(_ pacchetto: Pacchetto, _ posto: String, lato: CGFloat) async -> UIImage? {
        if let fatta = pronta(posto) { return fatta }
        let immagine = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let dati = try? pacchetto.apri(posto),
                  let fonte = CGImageSourceCreateWithData(dati as CFData, nil) else { return nil }
            let opzioni: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(64, lato),
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(fonte, 0, opzioni as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }.value
        if let immagine {
            cache.setObject(immagine, forKey: posto as NSString,
                            cost: Int(immagine.size.width * immagine.size.height * immagine.scale * immagine.scale * 4))
        }
        return immagine
    }
}

struct GruppoDelGiorno: Identifiable {
    let giorno: String?
    var scatti: [Scatto]
    var id: String { giorno ?? "senza-data" }
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

    var gruppi: [GruppoDelGiorno] {
        var uscita: [GruppoDelGiorno] = []
        for s in scatti {
            if let ultimo = uscita.last, ultimo.giorno == s.giorno {
                uscita[uscita.count - 1].scatti.append(s)
            } else {
                uscita.append(GruppoDelGiorno(giorno: s.giorno, scatti: [s]))
            }
        }
        return uscita
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
    @StateObject private var elenco: Elenco
    @State private var scelti: Set<Int64>?
    @State private var chiedeTogli = false
    @AppStorage("visore.colonne") private var colonne = 3
    @AppStorage("visore.proporzioni") private var proporzioni = false
    @State private var aperto: Aperto?
    @State private var visto: Int64 = 0
    @State private var pizzico: CGFloat = 1
    @State private var anteprima: Scatto?
    @State private var compatta = false
    @State private var anno: String?
    @Namespace private var zoom

    struct Aperto: Identifiable {
        let indice: Int
        var id: Int { indice }
    }

    private static let livelli = [1, 3, 5, 7]

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
        GeometryReader { g in
            let largo = g.size.width > g.size.height * 1.2
            let quante = largo ? min(12, max(colonne + 2, colonne * 2 - 1)) : colonne
            let lato = floor((g.size.width - CGFloat(quante - 1) * 2) / CGFloat(quante))
            let gruppi = elenco.gruppi
            let linea = elenco.linea
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Testa(titolo: titolo, sottotitolo: sottotitoloVero,
                              indietro: torna) { azioni }
                            .id("cima")
                        if radice { pillole(linea, proxy) }
                        if let testa { testa }
                        ForEach(gruppi) { gruppo in
                            Intestazione(giorno: gruppo.giorno, luoghi: luoghi(gruppo), quante: quanteDel(gruppo),
                                         tutte: scelti == nil ? nil : tutteDelGiorno(gruppo, linea))
                                .id("giorno-" + gruppo.id)
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(lato), spacing: 2), count: quante),
                                      spacing: 2) {
                                ForEach(gruppo.scatti) { s in
                                    Riquadro(pacchetto: pacchetto, scatto: s, lato: lato, proporzioni: proporzioni,
                                             cuore: cassetto.haIlCuore(s), scelto: scelti.map { $0.contains(s.id) },
                                             tenuto: { anteprima = $0 ? s : (anteprima?.id == s.id ? nil : anteprima) })
                                        .matchedTransitionSource(id: s.id, in: zoom)
                                        .id(s.id)
                                        .onTapGesture { if scelti == nil { apri(s) } else { cambia(s.id) } }
                                        .onAppear { if s.id == elenco.scatti.last?.id { elenco.altri() } }
                                }
                            }
                        }
                        if elenco.scatti.isEmpty {
                            Vuoto(titolo: "Nessuna foto", testo: vuota)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
                .segueLaTesta($compatta)
                .scaleEffect(pizzico, anchor: .top)
                .simultaneousGesture(MagnifyGesture()
                    .onChanged { pizzico = min(1.4, max(0.7, $0.magnification)) }
                    .onEnded { fine in
                        withAnimation(.snappy) {
                            cambiaColonne(fine.magnification)
                            pizzico = 1
                        }
                    })
                .overlay(alignment: .trailing) {
                    BarraAnni(linea: linea) { i in vai(i, linea, proxy) }
                        .padding(.top, 120)
                }
                .onChange(of: visto) { _, id in
                    if aperto != nil { proxy.scrollTo(id, anchor: .center) }
                }
                .onChange(of: cima) { _, _ in
                    withAnimation(Moto.scena) { proxy.scrollTo("cima", anchor: .top) }
                    anno = nil
                }
                .fullScreenCover(item: $aperto) { a in
                    FotoAperta(pacchetto: pacchetto, elenco: elenco, inizio: a.indice, visto: $visto, raccolta: raccolta)
                        .environmentObject(cassetto)
                        .environmentObject(annunci)
                        .environmentObject(interfaccia)
                        .navigationTransition(.zoom(sourceID: visto, in: zoom))
                }
            }
        }
        .testaCompatta(titolo, visibile: compatta, indietro: torna) { azioni }
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
        .onChange(of: aperto?.id) { _, nuovo in cassetto.aperta = nuovo != nil }
        .onChange(of: scelti == nil) { _, nessuno in interfaccia.scegliendo = !nessuno }
        .onDisappear { if scelti != nil { scelti = nil; interfaccia.scegliendo = false } }
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

    private func pillole(_ linea: Linea, _ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                NavigationLink(value: TutteLeRaccolte()) {
                    Pillola(testo: "Raccolte", simbolo: "heart")
                }
                .buttonStyle(Premuto())
                Rectangle().fill(Tinta.linea).frame(width: 0.5, height: 20).padding(.horizontal, 4)
                Button {
                    anno = nil
                    withAnimation(Moto.scena) { proxy.scrollTo("cima", anchor: .top) }
                } label: { Pillola(testo: "Tutte", scelta: anno == nil) }
                .buttonStyle(Premuto())
                ForEach(linea.anni, id: \.anno) { a in
                    Button {
                        anno = a.anno
                        if let i = linea.giorni.firstIndex(where: { $0.hasPrefix(a.anno) }) { vai(i, linea, proxy) }
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

    private func vai(_ i: Int, _ linea: Linea, _ proxy: ScrollViewProxy) {
        guard linea.giorni.indices.contains(i) else { return }
        let giorno = linea.giorni[i]
        elenco.almeno(linea.prima[i] + (elenco.perGiorno[giorno]?.quanti ?? 1))
        proxy.scrollTo("giorno-" + giorno, anchor: .top)
    }

    private func luoghi(_ gruppo: GruppoDelGiorno) -> [String] {
        if let g = gruppo.giorno, let r = elenco.perGiorno[g] { return r.luoghi }
        var visti: [String: Int] = [:]
        for s in gruppo.scatti { if let l = s.luogo { visti[l, default: 0] += 1 } }
        return visti.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    private func apri(_ s: Scatto) {
        if let i = elenco.scatti.firstIndex(where: { $0.id == s.id }) {
            visto = s.id
            aperto = Aperto(indice: i)
        }
    }

    private func cambiaColonne(_ quanto: CGFloat) {
        guard let i = GrigliaGiorni.livelli.firstIndex(of: colonne) else { colonne = 3; return }
        if quanto > 1.15, i > 0 { colonne = GrigliaGiorni.livelli[i - 1] }
        if quanto < 0.85, i < GrigliaGiorni.livelli.count - 1 { colonne = GrigliaGiorni.livelli[i + 1] }
    }
}

struct BarraAnni: View {
    let linea: Linea
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
                    ForEach(linea.anni, id: \.anno) { a in
                        Text(a.anno)
                            .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(Tinta.tenue)
                            .fixedSize()
                            .offset(x: -30, y: min(alto - 14, a.frazione * alto))
                    }
                    if let i = linea.indice(a: dito / alto), linea.giorni.indices.contains(i) {
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
                    if let i = linea.indice(a: v.location.y / alto), i != ultimo {
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

struct Riquadro: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    let lato: CGFloat
    let proporzioni: Bool
    var cuore = false
    var scelto: Bool? = nil
    let tenuto: (Bool) -> Void
    @State private var immagine: UIImage?
    @State private var visto = false
    @GestureState private var premuto = false
    @Environment(\.displayScale) private var scala

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let immagine {
                Tinta.pozzo
                let forma = misura
                Image(uiImage: immagine).resizable().scaledToFill()
                    .frame(width: forma.width, height: forma.height).clipped()
                    .frame(width: lato, height: lato)
                    .opacity(visto ? 1 : 0)
                    .onAppear { withAnimation(Moto.passo) { visto = true } }
            } else {
                Luccichio()
            }
            if scatto.video {
                Text(Testi.durata(scatto.durataMs))
                    .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 2).padding(5)
            } else if scatto.live, lato > 60 {
                Image(systemName: "livephoto")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 2).padding(5)
            }
            if cuore, lato > 40 {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 2).padding(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .transition(.scale.combined(with: .opacity))
            }
            if let scelto {
                if scelto { Tinta.accento.opacity(0.18) }
                Image(systemName: scelto ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .symbolRenderingMode(scelto ? .palette : .monochrome)
                    .foregroundStyle(.white, Tinta.arancio)
                    .shadow(color: .black.opacity(0.4), radius: 2).padding(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: lato, height: lato)
        .clipShape(RoundedRectangle(cornerRadius: lato > 60 ? 3 : 1, style: .continuous))
        .scaleEffect(scelto == true ? 0.92 : 1)
        .animation(Moto.molla, value: scelto)
        .animation(Moto.molla, value: cuore)
        .contentShape(Rectangle())
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($premuto) { valore, stato, _ in
                if case .second(true, _) = valore { stato = true }
            })
        .onChange(of: premuto) { _, si in tenuto(si) }
        .task(id: scatto.id) {
            immagine = Miniature.tutte.pronta(scatto.mini ?? scatto.posto)
            if immagine != nil { visto = true }
            if immagine == nil {
                immagine = await Miniature.tutte.carica(pacchetto, scatto.mini ?? scatto.posto, lato: lato * scala)
            }
        }
    }

    private var misura: CGSize {
        guard proporzioni, let w = scatto.larghezza, let h = scatto.altezza, w > 0, h > 0 else {
            return CGSize(width: lato, height: lato)
        }
        let r = CGFloat(w) / CGFloat(h)
        return r >= 1 ? CGSize(width: lato, height: lato / r) : CGSize(width: lato * r, height: lato)
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
    @AppStorage(Giro.chiave) private var giroVisto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("Impostazioni").font(Carattere.titolo).foregroundStyle(Tinta.ink)
                    Spacer()
                    Button("Fine") { chiudi() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tinta.accento)
                }
                .padding(.top, 18)
                GruppoImpostazioni(titolo: "Firma") {
                    if let scade = Firma.scadenza() {
                        Text(Firma.aParole(fino: scade)).font(Carattere.piccolo).foregroundStyle(Tinta.ink)
                            .padding(.top, 11)
                    }
                    Spiegazione(testo: "Si rinnova con AltStore, avviando AltServer sul portatile. Rinnovare non tocca niente. "
                                + "Cancellare l'app e rimetterla porta via il pacchetto: andrebbe ricopiato tutto dal PC.")
                }
                GruppoImpostazioni(titolo: "Griglia",
                                   nota: "Spento: miniature quadrate, piene. Acceso: ogni foto con la sua forma, dentro il suo quadrato. "
                                       + "Pizzica la griglia per vedere più foto o più grandi.") {
                    Toggle(isOn: $proporzioni) { Text("Proporzioni vere").font(.system(size: 15)).foregroundStyle(Tinta.ink) }
                        .tint(Tinta.accento)
                        .padding(.vertical, 6)
                }
                GruppoImpostazioni(titolo: "Blocco") {
                    Spiegazione(testo: "Il Visore si chiude appena esci o cambi app, e al rientro chiede Face ID. "
                                + "La password torna ogni 7 giorni, dopo un riavvio e dopo 5 Face ID falliti.")
                }
                GruppoImpostazioni(titolo: "Riservatezza") {
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
                GruppoImpostazioni(titolo: "Foto aperta") {
                    Spiegazione(testo: "Un tocco nasconde e rimostra tutto. Tieni premuto su una live photo: si muove finché tieni. "
                                + "Due tocchi mettono il cuore. In basso le miniature di prima e dopo: toccane una per saltarci. "
                                + "Giù di scatto chiude, su mostra le informazioni.")
                }
                GruppoImpostazioni(titolo: "Pacchetto") {
                    let info = pacchetto.archivio.informazioni()
                    VoceImpostazione(nome: "Foto e video", valore: Testi.numero((try? pacchetto.archivio.quanti()) ?? 0))
                    if let fatto = info["fatto_il"] { VoceImpostazione(nome: "Fatto il", valore: Testi.istante(fatto)) }
                    if let n = info["nuove_ultimo_travaso"], let quante = Int(n), quante > 0 {
                        VoceImpostazione(nome: "Nuove nell'ultima copia", valore: Testi.numero(quante))
                    }
                    if let v = info["versione_officina"] { VoceImpostazione(nome: "Officina", valore: v) }
                    VoceImpostazione(nome: "Visore",
                                     valore: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                }
                Button("Rivedi il giro di benvenuto") {
                    chiudi()
                    giroVisto = false
                }
                .buttonStyle(TastoBordo())
                GruppoImpostazioni(titolo: "Licenze") {
                    Spiegazione(testo: "SQLite: pubblico dominio. Crittografia: CryptoKit di Apple, compresa nel sistema. "
                                + "Carattere Source Serif 4: SIL Open Font License. "
                                + "Il resto del Visore è scritto per questo progetto e non usa librerie di altri.")
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
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
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Tinta.lineaForte, lineWidth: 0.5))
        .shadow(color: Tinta.ombra, radius: 18, y: 8)
        .animation(Moto.passo, value: quante)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
    }
}
