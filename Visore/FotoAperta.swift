import SwiftUI
import UIKit
import VisoreKit

enum Gesti {
    static let contattoPerLaLive: TimeInterval = 0.17
    static let primoMovimento: CGFloat = 8
    static let chiudeDopo: CGFloat = 110
    static let chiudeVeloce: CGFloat = 900
    static let liveDopo: CGFloat = 70
    static let tocco: TimeInterval = 0.3
}

final class Originali {
    static let tutti = Originali()
    private let cache = NSCache<NSString, UIImage>()

    init() { cache.countLimit = 3 }

    func sfuma() { cache.removeAllObjects() }

    func pronto(_ posto: String) -> UIImage? { cache.object(forKey: posto as NSString) }

    func carica(_ pacchetto: Pacchetto, _ posto: String) async -> UIImage? {
        if let fatto = pronto(posto) { return fatto }
        let immagine = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let dati = try? pacchetto.apri(posto) else { return nil }
            var regole = UIImageReader.Configuration()
            regole.prefersHighDynamicRange = true
            return UIImageReader(configuration: regole).image(data: dati)?.preparingForDisplay()
        }.value
        if let immagine { cache.setObject(immagine, forKey: posto as NSString) }
        return immagine
    }
}

struct FotoAperta: View {
    let pacchetto: Pacchetto
    @ObservedObject var elenco: Elenco
    let inizio: Int
    @Environment(\.dismiss) private var chiudi
    @State private var corrente: Int64?
    @State private var movimentoAcceso = false
    @State private var controlli = false
    @State private var info: Scatto?
    @State private var ingrandita = false
    @State private var giu: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(1 - min(0.6, giu / 400)).ignoresSafeArea()
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(elenco.scatti) { s in
                        Pagina(pacchetto: pacchetto, scatto: s, attiva: corrente == s.id,
                               movimentoAcceso: $movimentoAcceso, controlli: $controlli,
                               ingrandita: $ingrandita, giu: $giu,
                               chiudi: { chiudi() }, mostraInfo: { info = s })
                            .containerRelativeFrame(.horizontal)
                            .id(s.id)
                            .onAppear { if s.id == elenco.scatti.last?.id { elenco.altri() } }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $corrente)
            .scrollIndicators(.hidden)
            .scrollDisabled(ingrandita)
            .ignoresSafeArea()
            if controlli, let s = elenco.scatti.first(where: { $0.id == corrente }) {
                VStack {
                    HStack {
                        Button { chiudi() } label: {
                            Image(systemName: "chevron.left").font(.title3.weight(.semibold)).padding(10)
                        }
                        Spacer()
                        VStack(spacing: 0) {
                            Text(Testi.giorno(s.giorno)).font(.headline)
                            if let ora = Testi.ora(s.dataLocale) { Text(ora).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Button { info = s } label: {
                            Image(systemName: "info.circle").font(.title3).padding(10)
                        }
                    }
                    .padding(.horizontal, 8)
                    .background(.ultraThinMaterial)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .statusBarHidden(!controlli)
        .preferredColorScheme(.dark)
        .onAppear {
            if elenco.scatti.indices.contains(inizio) { corrente = elenco.scatti[inizio].id }
        }
        .onChange(of: corrente) { _, nuovo in prepara(intorno: nuovo) }
        .sheet(item: $info) { s in
            Informazioni(scatto: s)
                .presentationDetents([.fraction(0.45)])
                .presentationDragIndicator(.visible)
        }
    }

    private func prepara(intorno id: Int64?) {
        guard let id, let i = elenco.scatti.firstIndex(where: { $0.id == id }) else { return }
        for j in [i + 1, i - 1] where elenco.scatti.indices.contains(j) {
            let s = elenco.scatti[j]
            guard !s.video else { continue }
            let p = pacchetto
            Task { _ = await Originali.tutti.carica(p, s.posto) }
        }
    }
}

struct Pagina: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    let attiva: Bool
    @Binding var movimentoAcceso: Bool
    @Binding var controlli: Bool
    @Binding var ingrandita: Bool
    @Binding var giu: CGFloat
    let chiudi: () -> Void
    let mostraInfo: () -> Void

    @StateObject private var movimento = Movimento()
    @State private var piccola: UIImage?
    @State private var grande: UIImage?
    @State private var rotta = false
    @State private var spostamento: CGSize = .zero
    @State private var scala: CGFloat = 1
    @State private var scalaPrima: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panPrima: CGSize = .zero
    @State private var inizioTocco: Date?
    @State private var modo: Modo?

    enum Modo { case chiudi, live, info, orizzontale, sposta }

    var body: some View {
        ZStack {
            if let immagine = grande ?? piccola {
                Image(uiImage: immagine)
                    .resizable()
                    .allowedDynamicRange(grande != nil ? .high : .standard)
                    .scaledToFit()
            }
            if scatto.live || scatto.video {
                StratoVideo(lettore: movimento.lettore)
                    .opacity(movimento.inCorso ? 1 : 0)
                    .allowsHitTesting(false)
            }
            if rotta || movimento.rotto {
                VStack {
                    Spacer()
                    Text(scatto.video ? "Questo video non si apre qui: resta la miniatura."
                                      : "Questa foto non si apre qui: resta la miniatura.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 40)
                }
            }
            if scatto.video, controlli, movimento.pronto {
                ComandiVideo(movimento: movimento)
            } else if scatto.live, controlli, movimento.pronto {
                VStack {
                    Spacer()
                    HStack {
                        Button { movimento.muto.toggle() } label: {
                            Image(systemName: movimento.muto ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .padding(12)
                        }
                        Spacer()
                    }
                    .background(.ultraThinMaterial)
                }
            }
        }
        .scaleEffect(scala * (modo == .chiudi ? max(0.75, 1 - spostamento.height / 1200) : 1))
        .offset(x: pan.width + (modo == .chiudi ? spostamento.width : 0),
                y: pan.height + (modo == .chiudi ? max(0, spostamento.height) : modo == .live ? spostamento.height * 0.15 : 0))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(dito)
        .simultaneousGesture(pizzico)
        .task(id: scatto.id) { await carica() }
        .onChange(of: attiva) { _, si in aggiorna(attiva: si) }
        .onChange(of: movimentoAcceso) { _, _ in aggiorna(attiva: attiva) }
        .onDisappear {
            movimento.ferma()
            scala = 1
            pan = .zero
        }
    }

    private var dito: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                if inizioTocco == nil { inizioTocco = v.time }
                let t = v.translation
                if modo == nil, max(abs(t.width), abs(t.height)) > Gesti.primoMovimento {
                    modo = sceglie(t, dopo: v.time.timeIntervalSince(inizioTocco ?? v.time))
                    if modo == .live, !movimentoAcceso { movimento.unGiro() }
                }
                switch modo {
                case .sposta:
                    pan = CGSize(width: panPrima.width + t.width, height: panPrima.height + t.height)
                case .chiudi:
                    spostamento = t
                    giu = max(0, t.height)
                case .live:
                    spostamento = t
                default:
                    break
                }
            }
            .onEnded { v in
                defer {
                    inizioTocco = nil
                    modo = nil
                    giu = 0
                }
                let t = v.translation
                let durata = v.time.timeIntervalSince(inizioTocco ?? v.time)
                switch modo {
                case .none where durata < Gesti.tocco:
                    tocco()
                case .chiudi?:
                    if t.height > Gesti.chiudeDopo || v.velocity.height > Gesti.chiudeVeloce {
                        chiudi()
                    } else {
                        withAnimation(.spring(duration: 0.3)) { spostamento = .zero }
                    }
                case .live?:
                    withAnimation(.spring(duration: 0.3)) { spostamento = .zero }
                    if t.height > Gesti.liveDopo {
                        movimentoAcceso.toggle()
                    } else if !movimentoAcceso {
                        movimento.ferma()
                    }
                case .info?:
                    if t.height < -40 {
                        controlli = true
                        mostraInfo()
                    }
                case .sposta?:
                    panPrima = pan
                default:
                    break
                }
            }
    }

    private var pizzico: some Gesture {
        MagnifyGesture()
            .onChanged { v in scala = min(8, max(1, scalaPrima * v.magnification)) }
            .onEnded { _ in
                if scala < 1.05 {
                    withAnimation(.spring(duration: 0.3)) {
                        scala = 1
                        pan = .zero
                    }
                    panPrima = .zero
                }
                scalaPrima = scala
                ingrandita = scala > 1
            }
    }

    private func sceglie(_ t: CGSize, dopo: TimeInterval) -> Modo {
        if scala > 1 { return .sposta }
        if abs(t.width) > abs(t.height) { return .orizzontale }
        if t.height < 0 { return .info }
        if scatto.live, dopo >= Gesti.contattoPerLaLive { return .live }
        return .chiudi
    }

    private func tocco() {
        if scatto.live {
            if movimentoAcceso {
                movimentoAcceso = false
            } else {
                movimento.unGiro()
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { controlli.toggle() }
        }
    }

    private func carica() async {
        let mini = scatto.mini ?? scatto.posto
        piccola = Miniature.tutte.pronta(mini)
        if piccola == nil {
            piccola = await Miniature.tutte.carica(pacchetto, mini, lato: 600)
        }
        if scatto.video {
            await movimento.prepara(pacchetto: pacchetto, posto: scatto.posto)
        } else {
            grande = Originali.tutti.pronto(scatto.posto)
            if grande == nil { grande = await Originali.tutti.carica(pacchetto, scatto.posto) }
            rotta = grande == nil
            if scatto.live, let m = scatto.postoMovimento {
                await movimento.prepara(pacchetto: pacchetto, posto: m)
            }
        }
        aggiorna(attiva: attiva)
    }

    private func aggiorna(attiva: Bool) {
        guard movimento.pronto else { return }
        if !attiva {
            movimento.ferma()
            return
        }
        if scatto.video {
            if !movimento.inLoop { movimento.inAnello() }
        } else if scatto.live {
            if movimentoAcceso, !movimento.inLoop { movimento.inAnello() }
            if !movimentoAcceso, movimento.inLoop { movimento.ferma() }
        }
    }
}

struct ComandiVideo: View {
    @ObservedObject var movimento: Movimento
    @State private var trascino: Double?

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 6) {
                Slider(value: Binding(get: { trascino ?? movimento.secondi },
                                      set: { trascino = $0 }),
                       in: 0...max(0.1, movimento.durata)) { inizio in
                    if !inizio, let trascino {
                        movimento.vaiA(trascino)
                        self.trascino = nil
                    }
                }
                HStack {
                    Text(Testi.durata(Int((trascino ?? movimento.secondi) * 1000))).monospacedDigit()
                    Spacer()
                    Button { movimento.pausaOVai() } label: {
                        Image(systemName: movimento.inPausa ? "play.fill" : "pause.fill").padding(8)
                    }
                    Spacer()
                    Button { movimento.muto.toggle() } label: {
                        Image(systemName: movimento.muto ? "speaker.slash.fill" : "speaker.wave.2.fill").padding(8)
                    }
                    Text(Testi.durata(Int(movimento.durata * 1000))).monospacedDigit()
                }
                .font(.footnote)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }
}

struct Informazioni: View {
    let scatto: Scatto

    var body: some View {
        List {
            Section {
                LabeledContent("Giorno", value: Testi.giorno(scatto.giorno))
                if let ora = Testi.ora(scatto.dataLocale) { LabeledContent("Ora", value: ora) }
                if let luogo = scatto.luogo { LabeledContent("Luogo", value: luogo) }
            }
            if let nota = scatto.nota, !nota.isEmpty {
                Section("Nota") { Text(nota) }
            }
        }
    }
}
