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
    private let prendi: (Int, Int) -> [Scatto]

    init(prendi: @escaping (Int, Int) -> [Scatto]) {
        self.prendi = prendi
        altri()
    }

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
    @StateObject private var elenco: Elenco
    let riassunto: [String: Giorno]
    @AppStorage("visore.colonne") private var colonne = 3
    @AppStorage("visore.proporzioni") private var proporzioni = false
    @State private var aperto: Aperto?
    @State private var visto: Int64 = 0
    @State private var pizzico: CGFloat = 1
    @State private var anteprima: Scatto?
    @Namespace private var zoom

    struct Aperto: Identifiable {
        let indice: Int
        var id: Int { indice }
    }

    private static let livelli = [1, 3, 5, 7]

    init(pacchetto: Pacchetto, elenco: @autoclosure @escaping () -> Elenco, riassunto: [String: Giorno] = [:]) {
        self.pacchetto = pacchetto
        self.riassunto = riassunto
        _elenco = StateObject(wrappedValue: elenco())
    }

    var body: some View {
        GeometryReader { g in
            let lato = (g.size.width - CGFloat(colonne - 1) * 2) / CGFloat(colonne)
            let gruppi = elenco.gruppi
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(gruppi) { gruppo in
                            Intestazione(giorno: gruppo.giorno, luoghi: luoghi(gruppo))
                                .id("giorno-" + gruppo.id)
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(lato), spacing: 2), count: colonne),
                                      spacing: 2) {
                                ForEach(gruppo.scatti) { s in
                                    Riquadro(pacchetto: pacchetto, scatto: s, lato: lato, proporzioni: proporzioni,
                                             tenuto: { anteprima = $0 ? s : (anteprima?.id == s.id ? nil : anteprima) })
                                        .matchedTransitionSource(id: s.id, in: zoom)
                                        .id(s.id)
                                        .onTapGesture { apri(s) }
                                        .onAppear { if s.id == elenco.scatti.last?.id { elenco.altri() } }
                                }
                            }
                        }
                        if elenco.scatti.isEmpty {
                            Text("Qui non ci sono foto.").foregroundStyle(.secondary).padding()
                        }
                    }
                }
                .scaleEffect(pizzico, anchor: .top)
                .gesture(MagnifyGesture()
                    .onChanged { pizzico = min(1.4, max(0.7, $0.magnification)) }
                    .onEnded { fine in
                        withAnimation(.snappy) {
                            cambiaColonne(fine.magnification)
                            pizzico = 1
                        }
                    })
                .overlay(alignment: .trailing) {
                    BarraAnni(linea: linea(gruppi)) { i in vai(i, linea(gruppi), proxy) }
                }
                .onChange(of: visto) { _, id in
                    if aperto != nil { proxy.scrollTo(id, anchor: .center) }
                }
                .fullScreenCover(item: $aperto) { a in
                    FotoAperta(pacchetto: pacchetto, elenco: elenco, inizio: a.indice, visto: $visto)
                        .navigationTransition(.zoom(sourceID: visto, in: zoom))
                }
            }
        }
        .overlay {
            if let anteprima {
                Anteprima(pacchetto: pacchetto, scatto: anteprima)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(duration: 0.25), value: anteprima?.id)
        .sensoryFeedback(.impact(weight: .medium), trigger: anteprima?.id) { _, nuovo in nuovo != nil }
    }

    private func linea(_ gruppi: [GruppoDelGiorno]) -> Linea {
        if !riassunto.isEmpty {
            return Linea(riassunto.values.compactMap { r in r.giorno.map { ($0, r.quanti) } }
                .sorted { $0.0 > $1.0 })
        }
        return Linea(gruppi.compactMap { gr in gr.giorno.map { ($0, gr.scatti.count) } })
    }

    private func vai(_ i: Int, _ linea: Linea, _ proxy: ScrollViewProxy) {
        let giorno = linea.giorni[i]
        if !riassunto.isEmpty {
            elenco.almeno(linea.prima[i] + (riassunto[giorno]?.quanti ?? 1))
        }
        proxy.scrollTo("giorno-" + giorno, anchor: .top)
    }

    private func luoghi(_ gruppo: GruppoDelGiorno) -> [String] {
        if let g = gruppo.giorno, let r = riassunto[g] { return r.luoghi }
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
                            .font(.caption2.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .offset(x: -30, y: min(alto - 14, a.frazione * alto))
                    }
                    if let i = linea.indice(a: dito / alto), linea.giorni.indices.contains(i) {
                        Text(Testi.mese(linea.giorni[i]))
                            .font(.footnote.weight(.semibold))
                            .fixedSize()
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.regularMaterial, in: Capsule())
                            .offset(x: -72, y: min(max(0, dito - 16), alto - 32))
                    }
                    Capsule().fill(.white.opacity(0.85))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Testi.giorno(giorno)).font(.title3.bold())
            if let l = Testi.luoghi(luoghi) {
                Text(l).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Luccichio: View {
    @State private var acceso = false

    var body: some View {
        Rectangle()
            .fill(Color(white: acceso ? 0.17 : 0.10))
            .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { acceso = true } }
    }
}

struct Riquadro: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    let lato: CGFloat
    let proporzioni: Bool
    let tenuto: (Bool) -> Void
    @State private var immagine: UIImage?
    @GestureState private var premuto = false
    @Environment(\.displayScale) private var scala

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let immagine {
                Color.black
                let forma = misura
                Image(uiImage: immagine).resizable().scaledToFill()
                    .frame(width: forma.width, height: forma.height).clipped()
                    .frame(width: lato, height: lato)
            } else {
                Luccichio()
            }
            if scatto.video {
                Text(Testi.durata(scatto.durataMs))
                    .font(.caption2.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(.white).shadow(radius: 2).padding(4)
            } else if scatto.live, lato > 60 {
                Image(systemName: "livephoto")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white).shadow(radius: 2).padding(4)
            }
        }
        .frame(width: lato, height: lato)
        .clipShape(RoundedRectangle(cornerRadius: 1))
        .contentShape(Rectangle())
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($premuto) { valore, stato, _ in
                if case .second(true, _) = valore { stato = true }
            })
        .onChange(of: premuto) { _, si in tenuto(si) }
        .task(id: scatto.id) {
            immagine = Miniature.tutte.pronta(scatto.mini ?? scatto.posto)
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
            Rectangle().fill(.black.opacity(0.6)).ignoresSafeArea()
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
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 20)
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

struct Impostazioni: View {
    @AppStorage("visore.proporzioni") private var proporzioni = false
    @Environment(\.dismiss) private var chiudi

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Proporzioni vere", isOn: $proporzioni)
                } footer: {
                    Text("Spento: miniature quadrate, piene. Acceso: ogni foto con la sua forma, dentro il suo quadrato.")
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fine") { chiudi() } }
        }
    }
}
