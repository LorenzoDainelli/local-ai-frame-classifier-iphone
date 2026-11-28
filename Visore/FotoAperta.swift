import SwiftUI
import UIKit
import VisoreKit

enum Gesti {
    static let tieniPerLaLive: TimeInterval = 0.28
    static let primoMovimento: CGFloat = 8
    static let chiudeDopo: CGFloat = 110
    static let chiudeVeloce: CGFloat = 900
    static let tocco: TimeInterval = 0.3
    static let doppio: TimeInterval = 0.3
    static let barra: CGFloat = 124

    @MainActor static var bordi: UIEdgeInsets {
        let finestra = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        return finestra?.safeAreaInsets ?? .zero
    }

    @MainActor static var sopraLaBarra: CGFloat { barra + bordi.bottom }
    @MainActor static var sottoLaTesta: CGFloat { bordi.top + 62 }
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
    @Binding var visto: Int64
    var raccolta: Int64? = nil
    var rovescio = false
    @EnvironmentObject var cassetto: Cassetto
    @EnvironmentObject var annunci: Annunci
    @EnvironmentObject var interfaccia: Interfaccia
    @Environment(\.dismiss) private var chiudi
    @State private var colpi = 0
    @State private var corrente: Int64?
    @State private var controlli = true
    @State private var info: Scatto?
    @State private var ingrandita = false
    @State private var giu: CGFloat = 0
    @State private var caricate = 0

    init(pacchetto: Pacchetto, elenco: Elenco, inizio: Int, visto: Binding<Int64>,
         raccolta: Int64? = nil, rovescio: Bool = false) {
        self.pacchetto = pacchetto
        self.elenco = elenco
        self.inizio = inizio
        self._visto = visto
        self.raccolta = raccolta
        self.rovescio = rovescio
        let primo = elenco.scatti.indices.contains(inizio) ? elenco.scatti[inizio].id : nil
        self._corrente = State(initialValue: primo)
    }

    var body: some View {
        ZStack {
            (controlli ? Tinta.fondo : Color.black)
                .opacity(1 - min(0.7, giu / 360))
                .ignoresSafeArea()
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(elenco.scatti) { s in
                        Pagina(pacchetto: pacchetto, scatto: s, attiva: corrente == s.id, caricate: caricate,
                               controlli: $controlli, ingrandita: $ingrandita, giu: $giu,
                               chiudi: { chiudi() }, mostraInfo: { info = s },
                               doppio: { doppioTocco(s) })
                            .scaleEffect(x: rovescio ? -1 : 1, y: 1)
                            .containerRelativeFrame(.horizontal)
                            .id(s.id)
                            .onAppear { if s.id == elenco.scatti.last?.id { elenco.altri() } }
                    }
                }
                .scrollTargetLayout()
            }
            .scaleEffect(x: rovescio ? -1 : 1, y: 1)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $corrente)
            .scrollIndicators(.hidden)
            .scrollDisabled(ingrandita)
            .ignoresSafeArea()
            if controlli, giu == 0, let s = elenco.scatti.first(where: { $0.id == corrente }) {
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        Vetrino(simbolo: "chevron.left", etichetta: "Indietro") { chiudi() }
                        VStack(spacing: 1) {
                            Text(Testi.giorno(s.giorno)).font(Carattere.piccolo).foregroundStyle(Tinta.carta)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            if let ora = Testi.ora(s.dataLocale) {
                                Text(ora).font(.system(size: 12)).foregroundStyle(Tinta.carta.opacity(0.72))
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .vetro(Capsule(), ripiego: .ultraThinMaterial, bordo: false, suFoto: true)
                        .environment(\.colorScheme, .dark)
                        .contentTransition(.opacity)
                        .animation(Moto.passo, value: s.id)
                        .frame(maxWidth: .infinity)
                        Vetrino(simbolo: "info.circle", etichetta: "Informazioni") { info = s }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    Spacer(minLength: 0)
                    Striscia(pacchetto: pacchetto, elenco: elenco, corrente: $corrente, rovescio: rovescio)
                        .frame(height: 46)
                        .padding(.bottom, 12)
                    BarraFoto(scatto: s, raccolta: raccolta)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)
                }
                .transition(.opacity)
            }
            CuoreGrande(colpi: colpi)
        }
        .modifier(ConAnnunci(annunci: annunci, sopra: 128))
        .sensoryFeedback(.impact(weight: .light), trigger: colpi)
        .alert("Attenzione", isPresented: Binding(get: { cassetto.guaio != nil }, set: { if !$0 { cassetto.guaio = nil } })) {
            Button("OK") { cassetto.guaio = nil }
        } message: {
            Text(cassetto.guaio ?? "")
        }
        .statusBarHidden(!controlli)
        .animation(Moto.passo, value: controlli)
        .onAppear {
            if corrente == nil, elenco.scatti.indices.contains(inizio) { corrente = elenco.scatti[inizio].id }
        }
        .task(id: corrente) { await caricaIntorno(corrente) }
        .onChange(of: corrente) { _, nuovo in
            if let nuovo {
                visto = nuovo
                cassetto.vista(nuovo)
            }
            prepara(intorno: nuovo)
        }
        .sheet(item: $info) { s in
            Informazioni(pacchetto: pacchetto, scatto: s)
                .environmentObject(cassetto)
                .environmentObject(annunci)
                .environmentObject(interfaccia)
                .foglioStile()
        }
    }

    private func doppioTocco(_ s: Scatto) {
        if !cassetto.haIlCuore(s) {
            _ = cassetto.cuore([s.impronta], acceso: true)
        }
        colpi += 1
    }

    private func caricaIntorno(_ id: Int64?) async {
        guard let id, let i = elenco.scatti.firstIndex(where: { $0.id == id }) else { return }
        for j in [i, i + 1, i - 1] where elenco.scatti.indices.contains(j) {
            let s = elenco.scatti[j]
            let mini = s.mini ?? s.posto
            if Miniature.tutte.pronta(mini) == nil {
                _ = await Miniature.tutte.carica(pacchetto, mini, lato: 600)
                caricate += 1
            }
            if !s.video, Originali.tutti.pronto(s.posto) == nil {
                _ = await Originali.tutti.carica(pacchetto, s.posto)
                caricate += 1
            }
            guard !Task.isCancelled else { return }
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

struct Striscia: View {
    let pacchetto: Pacchetto
    @ObservedObject var elenco: Elenco
    @Binding var corrente: Int64?
    var rovescio = false
    @State private var alCentro: Int64?
    @State private var dito = false

    var body: some View {
        GeometryReader { g in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 2) {
                    ForEach(elenco.scatti) { s in
                        let qui = s.id == corrente && !dito
                        Fotina(pacchetto: pacchetto, scatto: s)
                            .frame(width: qui ? 58 : 30, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: qui ? 5 : 2, style: .continuous))
                            .padding(.horizontal, qui ? 6 : 0)
                            .scaleEffect(x: rovescio ? -1 : 1, y: 1)
                            .contentShape(Rectangle())
                            .id(s.id)
                            .onTapGesture { vaiA(s.id) }
                            .onAppear { if s.id == elenco.scatti.last?.id { elenco.altri() } }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(0, g.size.width / 2 - 15), for: .scrollContent)
            .scaleEffect(x: rovescio ? -1 : 1, y: 1)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $alCentro, anchor: .center)
            .onScrollPhaseChange { _, fase in
                let ora = fase == .interacting || fase == .decelerating
                if ora != dito { withAnimation(Moto.molla) { dito = ora } }
                if !ora, let corrente, alCentro != corrente {
                    withAnimation(Moto.passo) { alCentro = corrente }
                }
            }
            .onChange(of: alCentro) { _, nuovo in
                guard dito, let nuovo, nuovo != corrente else { return }
                vaiA(nuovo)
            }
            .onChange(of: corrente) { _, nuovo in
                guard !dito, let nuovo, nuovo != alCentro else { return }
                withAnimation(Moto.passo) { alCentro = nuovo }
            }
            .onAppear { alCentro = corrente }
        }
        .sensoryFeedback(.selection, trigger: corrente)
    }

    private func vaiA(_ id: Int64) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { corrente = id }
    }
}

struct Fotina: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    @State private var immagine: UIImage?

    var body: some View {
        ZStack {
            Tinta.pozzo
            if let immagine {
                Image(uiImage: immagine).resizable().scaledToFill()
            }
        }
        .clipped()
        .task(id: scatto.id) {
            let mini = scatto.mini ?? scatto.posto
            immagine = Miniature.tutte.pronta(mini)
            if immagine == nil { immagine = await Miniature.tutte.carica(pacchetto, mini, lato: 140) }
        }
    }
}

struct Pagina: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    let attiva: Bool
    var caricate = 0
    @Binding var controlli: Bool
    @Binding var ingrandita: Bool
    @Binding var giu: CGFloat
    let chiudi: () -> Void
    let mostraInfo: () -> Void
    let doppio: () -> Void

    @StateObject private var movimento = Movimento()
    @State private var ultimoTocco: Date?
    @State private var attesa: Task<Void, Never>?
    @State private var tieni: Task<Void, Never>?
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
    @State private var tenute = 0

    enum Modo { case chiudi, live, info, orizzontale, sposta }

    var body: some View {
        ZStack {
            let intera = grande ?? (scatto.video ? nil : Originali.tutti.pronto(scatto.posto))
            if let immagine = intera ?? piccola ?? Miniature.tutte.pronta(scatto.mini ?? scatto.posto) {
                Image(uiImage: immagine)
                    .resizable()
                    .allowedDynamicRange(intera != nil ? .high : .standard)
                    .scaledToFit()
            }
            if (scatto.live || scatto.video), movimento.inCorso {
                StratoVideo(lettore: movimento.lettore)
                    .allowedDynamicRange(.high)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(grandezza)
        .offset(spinta)
        .animation(Moto.passo, value: modo == .live)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { sopra }
        .contentShape(Rectangle())
        .gesture(dito)
        .simultaneousGesture(pizzico)
        .sensoryFeedback(.impact(weight: .medium), trigger: tenute)
        .task(id: scatto.id) { await carica() }
        .onChange(of: attiva) { _, si in aggiorna(attiva: si) }
        .onDisappear {
            attesa?.cancel()
            tieni?.cancel()
            movimento.ferma()
            scala = 1
            pan = .zero
        }
    }

    private var grandezza: CGFloat {
        var g = scala
        if modo == .chiudi { g *= max(0.75, 1 - spostamento.height / 1200) }
        if modo == .live { g *= 1.03 }
        return g
    }

    private var spinta: CGSize {
        guard modo == .chiudi else { return pan }
        return CGSize(width: pan.width + spostamento.width, height: pan.height + max(0, spostamento.height))
    }

    @ViewBuilder
    private var sopra: some View {
        let mostra = controlli && giu == 0 && modo != .chiudi
        ZStack {
            if scatto.live, mostra || movimento.inCorso {
                HStack(spacing: 5) {
                    Image(systemName: "livephoto").font(.system(size: 12, weight: .semibold))
                    Text("LIVE").font(.system(size: 11, weight: .bold)).tracking(0.8)
                }
                .foregroundStyle(movimento.inCorso ? Tinta.arancio : Tinta.carta)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .vetro(Capsule(), ripiego: .ultraThinMaterial, bordo: false, suFoto: true)
                .environment(\.colorScheme, .dark)
                .padding(.top, Gesti.sottoLaTesta)
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .allowsHitTesting(false)
            }
            if rotta || movimento.rotto {
                Text(scatto.video ? "Questo video non si apre qui: resta la miniatura."
                                  : "Questa foto non si apre qui: resta la miniatura.")
                    .font(.system(size: 13)).foregroundStyle(Tinta.carta)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .vetro(Capsule(), ripiego: .ultraThinMaterial, bordo: false, suFoto: true)
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, Gesti.sopraLaBarra + 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
            }
            if mostra, movimento.pronto, scatto.video {
                ComandiVideo(movimento: movimento)
                    .padding(.horizontal, 14)
                    .padding(.bottom, Gesti.sopraLaBarra + 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity)
            }
        }
        .animation(Moto.passo, value: mostra)
        .animation(Moto.passo, value: movimento.inCorso)
        .ignoresSafeArea()
    }

    private var dito: Dito {
        Dito(inizio: {
            inizioTocco = Date()
            if scatto.live, scala <= 1 { aspettaLaLive() }
        }, decide: { t in
            tieni?.cancel()
            if modo == .live { return true }
            modo = sceglie(t)
            if modo == .orizzontale {
                modo = nil
                return false
            }
            return true
        }, cambia: { t in
            switch modo {
            case .sposta:
                pan = CGSize(width: panPrima.width + t.width, height: panPrima.height + t.height)
            case .chiudi:
                spostamento = t
                giu = max(0, t.height)
            default:
                break
            }
        }, fine: { t, velocita, _ in
            finito(t, velocita)
        }, annulla: {
            tieni?.cancel()
            tieni = nil
            if modo == .live { movimento.ferma() }
            if modo == .chiudi { withAnimation(Moto.molla) { spostamento = .zero } }
            if modo == .sposta { panPrima = pan }
            inizioTocco = nil
            modo = nil
            giu = 0
        })
    }

    private func finito(_ t: CGSize, _ velocita: CGSize) {
        tieni?.cancel()
        tieni = nil
        defer {
            inizioTocco = nil
            modo = nil
            giu = 0
        }
        let adesso = Date()
        let durata = adesso.timeIntervalSince(inizioTocco ?? adesso)
        switch modo {
        case .none where durata < Gesti.tocco:
            if let prima = ultimoTocco, adesso.timeIntervalSince(prima) < Gesti.doppio {
                ultimoTocco = nil
                attesa?.cancel()
                attesa = nil
                doppio()
            } else {
                ultimoTocco = adesso
                attesa?.cancel()
                attesa = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Gesti.doppio))
                    guard !Task.isCancelled else { return }
                    ultimoTocco = nil
                    withAnimation(Moto.passo) { controlli.toggle() }
                }
            }
        case .chiudi?:
            if t.height > Gesti.chiudeDopo || velocita.height > Gesti.chiudeVeloce {
                chiudi()
            } else {
                withAnimation(Moto.molla) { spostamento = .zero }
            }
        case .live?:
            movimento.ferma()
        case .info?:
            if t.height < -40 { mostraInfo() }
        case .sposta?:
            panPrima = pan
        default:
            break
        }
    }

    private func aspettaLaLive() {
        tieni?.cancel()
        tieni = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Gesti.tieniPerLaLive))
            if !movimento.pronto, scatto.live, let m = scatto.postoMovimento {
                await movimento.prepara(pacchetto: pacchetto, posto: m)
            }
            guard !Task.isCancelled, modo == nil, movimento.pronto else { return }
            modo = .live
            tenute += 1
            movimento.unGiro()
        }
    }

    private var pizzico: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                tieni?.cancel()
                scala = min(8, max(1, scalaPrima * v.magnification))
            }
            .onEnded { _ in
                if scala < 1.05 {
                    withAnimation(Moto.molla) {
                        scala = 1
                        pan = .zero
                    }
                    panPrima = .zero
                }
                scalaPrima = scala
                ingrandita = scala > 1
            }
    }

    private func sceglie(_ t: CGSize) -> Modo {
        if scala > 1 { return .sposta }
        if abs(t.width) > abs(t.height) { return .orizzontale }
        if t.height < 0 { return .info }
        return .chiudi
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
        if scatto.video, !movimento.inLoop { movimento.inAnello() }
    }
}

struct ComandiVideo: View {
    @ObservedObject var movimento: Movimento
    @State private var trascino: Double?

    var body: some View {
        let tocco = trascino != nil
        VStack(spacing: 6) {
            if let trascino {
                HStack(spacing: 0) {
                    Text(Testi.tempoPreciso(trascino))
                    Spacer(minLength: 12)
                    Text(Testi.tempoTondo(max(0, movimento.durata - trascino)))
                }
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
            HStack(spacing: 6) {
                if !tocco {
                    Button { movimento.pausaOVai() } label: {
                        Image(systemName: movimento.inPausa ? "play.fill" : "pause.fill")
                            .font(.system(size: 17))
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(Premuto(quanto: 0.88))
                    .accessibilityLabel(movimento.inPausa ? "Avvia" : "Pausa")
                    .transition(.opacity.combined(with: .scale(scale: 0.7)))
                }
                BarraVideo(movimento: movimento, trascino: $trascino)
                if !tocco {
                    Button { movimento.muto.toggle() } label: {
                        Image(systemName: movimento.muto ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 15))
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(Premuto(quanto: 0.88))
                    .accessibilityLabel(movimento.muto ? "Attiva l'audio" : "Togli l'audio")
                    .transition(.opacity.combined(with: .scale(scale: 0.7)))
                }
            }
        }
        .animation(Moto.molla, value: tocco)
        .foregroundStyle(Tinta.carta)
        .padding(.horizontal, tocco ? 16 : 6)
        .padding(.vertical, tocco ? 8 : 2)
        .vetro(Capsule(), interattivo: true, ripiego: .ultraThinMaterial, bordo: false, suFoto: true)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: 560)
    }
}

struct BarraVideo: View {
    @ObservedObject var movimento: Movimento
    @Binding var trascino: Double?
    @State private var partenza: Double = 0
    @State private var andava = false

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation) { _ in
                let durata = max(0.1, movimento.durata)
                let adesso = trascino ?? movimento.adesso
                let parte = CGFloat(min(1, max(0, adesso / durata)))
                let spessa = trascino != nil
                ZStack(alignment: .leading) {
                    Capsule().fill(Tinta.carta.opacity(0.26))
                    Capsule().fill(Tinta.arancio)
                        .frame(width: max(spessa ? 10 : 5, g.size.width * parte))
                }
                .frame(height: spessa ? 10 : 5)
                .frame(maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesto in
                        let durata = max(0.1, movimento.durata)
                        if trascino == nil {
                            partenza = movimento.adesso
                            andava = movimento.fermaPerScorrere()
                        }
                        let nuovo = min(durata, max(0, partenza + Double(gesto.translation.width / max(1, g.size.width)) * durata))
                        trascino = nuovo
                        movimento.guarda(nuovo)
                    }
                    .onEnded { _ in
                        if let trascino { movimento.vaiA(trascino) }
                        if andava { movimento.riparti() }
                        withAnimation(Moto.molla) { trascino = nil }
                    }
            )
            .animation(Moto.molla, value: trascino != nil)
        }
        .frame(height: 40)
        .sensoryFeedback(.impact(weight: .light), trigger: trascino != nil)
        .accessibilityElement()
        .accessibilityLabel("Posizione nel video")
        .accessibilityValue(Testi.tempoTondo(movimento.secondi))
        .accessibilityAdjustableAction { verso in
            let passo = max(1, movimento.durata / 20)
            let nuovo = movimento.secondi + (verso == .increment ? passo : -passo)
            movimento.vaiA(min(movimento.durata, max(0, nuovo)))
        }
    }
}

extension Testi {
    static func tempoPreciso(_ secondi: Double) -> String { TempoVideo.passato(secondi) }
    static func tempoTondo(_ secondi: Double) -> String { TempoVideo.manca(secondi) }
}

struct Informazioni: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    @State private var dettagli: Dettagli?
    @State private var strada = NavigationPath()
    @State private var altezza: PresentationDetent = .fraction(0.5)

    var body: some View {
        NavigationStack(path: $strada) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Testi.giorno(scatto.giorno)).font(Carattere.titoletto).foregroundStyle(Tinta.ink)
                        let sotto = [Testi.ora(scatto.dataLocale), scatto.luogo].compactMap { $0 }
                        if !sotto.isEmpty {
                            Text(sotto.joined(separator: " · ")).font(Carattere.minore).foregroundStyle(Tinta.tenue)
                        }
                    }
                    .padding(.top, 22)
                    GruppoImpostazioni(titolo: "Scatto") {
                        VoceImpostazione(nome: "Tipo", valore: scatto.video ? "Video" : scatto.live ? "Live photo" : "Foto")
                        if let w = scatto.larghezza, let h = scatto.altezza {
                            VoceImpostazione(nome: "Misure", valore: "\(w) × \(h)")
                        }
                        if scatto.video, let d = scatto.durataMs {
                            VoceImpostazione(nome: "Durata", valore: Testi.durata(d))
                        }
                    }
                    if let persone = dettagli?.persone, !persone.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PERSONE").etichettaMaiuscola().padding(.horizontal, 4)
                            Fila {
                                ForEach(persone) { p in
                                    NavigationLink(value: p) {
                                        HStack(spacing: 7) {
                                            Volto(pacchetto: pacchetto, persona: p, lato: 26)
                                            Text(p.nome).lineLimit(1)
                                        }
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(Tinta.ink)
                                        .padding(.leading, 3).padding(.trailing, 13)
                                        .frame(height: 32)
                                        .background(Tinta.fondo, in: Capsule())
                                        .overlay(Capsule().stroke(Tinta.linea, lineWidth: 0.5))
                                    }
                                    .buttonStyle(Premuto())
                                }
                            }
                        }
                    }
                    if let nodi = dettagli?.nodi, !nodi.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NODI").etichettaMaiuscola().padding(.horizontal, 4)
                            Fila {
                                ForEach(nodi) { n in
                                    NavigationLink(value: n) {
                                        Pillola(testo: n.nome, simbolo: "square.grid.2x2")
                                    }
                                    .buttonStyle(Premuto())
                                }
                            }
                        }
                    }
                    if let nota = scatto.nota, !nota.isEmpty {
                        GruppoImpostazioni(titolo: "Nota") { Spiegazione(testo: nota) }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Tinta.superficie)
            .senzaBarraDiSistema()
            .destinazioni(pacchetto)
        }
        .environment(\.vaiA) { strada.spingi($0) }
        .presentationDetents([.fraction(0.5), .large], selection: $altezza)
        .onChange(of: strada.count) { _, n in withAnimation { altezza = n > 0 ? .large : .fraction(0.5) } }
        .task(id: scatto.id) { dettagli = try? pacchetto.archivio.dettagli(scatto.id) }
    }
}

struct BarraFoto: View {
    let scatto: Scatto
    let raccolta: Int64?
    @EnvironmentObject var cassetto: Cassetto
    @EnvironmentObject var annunci: Annunci
    @State private var chiedeTogli = false

    var body: some View {
        let acceso = cassetto.haIlCuore(scatto)
        HStack(spacing: 10) {
            Vetrino(simbolo: acceso ? "heart.fill" : "heart", etichetta: acceso ? "Togli il cuore" : "Metti il cuore",
                    acceso: acceso) {
                if cassetto.cuore([scatto.impronta], acceso: !acceso) {
                    annunci.di(acceso ? "Tolta dai preferiti" : "Nei preferiti", simbolo: acceso ? "heart.slash" : "heart.fill")
                }
            }
            .sensoryFeedback(.selection, trigger: acceso)
            Spacer()
            if let raccolta {
                Vetrino(simbolo: "rectangle.stack.badge.minus", etichetta: "Togli da questa raccolta") {
                    chiedeTogli = true
                }
                .confirmationDialog("Togliere dalla raccolta?", isPresented: $chiedeTogli, titleVisibility: .visible) {
                    Button("Togli questa foto", role: .destructive) {
                        if cassetto.togli([scatto.impronta], da: raccolta) {
                            annunci.di("Tolta dalla raccolta", simbolo: "rectangle.stack.badge.minus")
                        }
                    }
                } message: {
                    Text("La foto resta nell'archivio: esce solo da questa raccolta.")
                }
            }
            MenuRaccolta(impronte: { [scatto.impronta] }, fatto: {}) {
                FacciaVetrino(simbolo: "rectangle.stack.badge.plus")
            }
            .accessibilityLabel("Aggiungi a una raccolta")
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}
