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

struct GrigliaGiorni: View {
    let pacchetto: Pacchetto
    @StateObject private var elenco: Elenco
    let riassunto: [String: Giorno]
    @AppStorage("visore.colonne") private var colonne = 3
    @State private var aperto: Aperto?
    @State private var pizzico: CGFloat = 1

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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(elenco.gruppi) { gruppo in
                        Intestazione(giorno: gruppo.giorno, luoghi: luoghi(gruppo))
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(lato), spacing: 2), count: colonne),
                                  spacing: 2) {
                            ForEach(gruppo.scatti) { s in
                                Riquadro(pacchetto: pacchetto, scatto: s, lato: lato)
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
        }
        .fullScreenCover(item: $aperto) { a in
            FotoAperta(pacchetto: pacchetto, elenco: elenco, inizio: a.indice)
        }
    }

    private func luoghi(_ gruppo: GruppoDelGiorno) -> [String] {
        if let g = gruppo.giorno, let r = riassunto[g] { return r.luoghi }
        var visti: [String: Int] = [:]
        for s in gruppo.scatti { if let l = s.luogo { visti[l, default: 0] += 1 } }
        return visti.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    private func apri(_ s: Scatto) {
        if let i = elenco.scatti.firstIndex(where: { $0.id == s.id }) { aperto = Aperto(indice: i) }
    }

    private func cambiaColonne(_ quanto: CGFloat) {
        guard let i = GrigliaGiorni.livelli.firstIndex(of: colonne) else { colonne = 3; return }
        if quanto > 1.15, i > 0 { colonne = GrigliaGiorni.livelli[i - 1] }
        if quanto < 0.85, i < GrigliaGiorni.livelli.count - 1 { colonne = GrigliaGiorni.livelli[i + 1] }
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

struct Riquadro: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    let lato: CGFloat
    @State private var immagine: UIImage?
    @Environment(\.displayScale) private var scala

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle().fill(Color(white: 0.12))
            if let immagine {
                Image(uiImage: immagine).resizable().scaledToFill()
                    .frame(width: lato, height: lato).clipped()
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
        .task(id: scatto.id) {
            immagine = Miniature.tutte.pronta(scatto.mini ?? scatto.posto)
            if immagine == nil {
                immagine = await Miniature.tutte.carica(pacchetto, scatto.mini ?? scatto.posto, lato: lato * scala)
            }
        }
    }
}
