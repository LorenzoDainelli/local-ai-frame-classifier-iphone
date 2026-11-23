import SwiftUI
import UIKit
import VisoreKit

struct Ricetta: Equatable {
    var mescola = Mescola()
    var ritmo: Double = 5
    var primaICuori = false
    var audio = false
    var ricomincia = true
}

struct GiroCasuale: Identifiable, Equatable {
    let id = UUID()
    let ricetta: Ricetta
}

enum Tipi {
    struct Uno: Identifiable {
        let chiave: String
        let nome: String
        let simbolo: String
        var id: String { chiave }
    }

    static let elenco = [
        Uno(chiave: "foto", nome: "Foto", simbolo: "photo"), Uno(chiave: "live", nome: "Live", simbolo: "livephoto"),
        Uno(chiave: "video", nome: "Video", simbolo: "video"),
    ]

    static func aParole(_ scelti: Set<String>) -> String {
        let ordinati = Mescola.generiTutti.filter(scelti.contains)
        switch ordinati.count {
        case 3: return "Foto, Live e video insieme"
        case 1: return ["foto": "Solo foto", "live": "Solo Live", "video": "Solo video"][ordinati[0]] ?? ""
        case 2:
            let nomi = ["foto": "foto", "live": "Live", "video": "video"]
            let primo = nomi[ordinati[0]] ?? ""
            return primo.prefix(1).uppercased() + primo.dropFirst() + " e " + (nomi[ordinati[1]] ?? "") + " insieme"
        default: return ""
        }
    }

    static func scatti(_ n: Int) -> String {
        n == 1 ? "1 scatto" : "\(Testi.numero(n)) scatti"
    }
}

struct Segno: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY + r.height * 0.04))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.37, y: r.maxY - r.height * 0.12))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.14))
        return p
    }
}

struct Spunta: View {
    let acceso: Bool
    var lato: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().stroke(Tinta.lineaForte, lineWidth: 1.5).opacity(acceso ? 0 : 1)
            Circle().fill(Tinta.accento).scaleEffect(acceso ? 1 : 0.4).opacity(acceso ? 1 : 0)
            Segno()
                .trim(from: 0, to: acceso ? 1 : 0)
                .stroke(Tinta.suAccento, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .padding(lato * 0.28)
        }
        .frame(width: lato, height: lato)
        .animation(Moto.molla, value: acceso)
        .accessibilityHidden(true)
    }
}

struct Trema: ViewModifier {
    let volte: Int
    @Environment(\.accessibilityReduceMotion) private var piano

    @ViewBuilder
    func body(content: Content) -> some View {
        if piano {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat(0), trigger: volte) { v, x in
                v.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-5, duration: 0.06)
                    LinearKeyframe(5, duration: 0.07)
                    LinearKeyframe(-3, duration: 0.06)
                    LinearKeyframe(0, duration: 0.06)
                }
            }
        }
    }
}

struct Salta: ViewModifier {
    let acceso: Bool
    @Environment(\.accessibilityReduceMotion) private var piano

    @ViewBuilder
    func body(content: Content) -> some View {
        if piano {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat(1), trigger: acceso) { v, s in
                v.scaleEffect(s)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.88, duration: 0.08)
                    SpringKeyframe(1, duration: 0.34, spring: .bouncy)
                }
            }
        }
    }
}

struct TestaFoglio: View {
    let titolo: String
    let sotto: String
    let chiudi: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titolo).font(Carattere.titolo).foregroundStyle(Tinta.ink)
                Text(sotto).font(.system(size: 13)).foregroundStyle(Tinta.tenue)
            }
            Spacer(minLength: 8)
            Tondo(simbolo: "xmark", etichetta: "Chiudi", azione: chiudi)
        }
        .padding(.top, 22)
        .padding(.bottom, 4)
    }
}

struct TitolettoFoglio: View {
    let testo: String
    var azione: (String, () -> Void)? = nil

    var body: some View {
        HStack {
            Text(testo.uppercased()).etichettaMaiuscola()
            Spacer(minLength: 8)
            if let azione {
                Button(azione.0, action: azione.1)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Tinta.accento)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(Moto.passo, value: azione?.0)
        .padding(.horizontal, 2)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }
}

struct Interruttore: View {
    let nome: String
    var nota: String? = nil
    @Binding var valore: Bool

    var body: some View {
        Toggle(isOn: $valore) {
            VStack(alignment: .leading, spacing: 2) {
                Text(nome).font(.system(size: 15)).foregroundStyle(Tinta.ink)
                if let nota {
                    Text(nota).font(.system(size: 12.5)).foregroundStyle(Tinta.tenue)
                }
            }
        }
        .tint(Tinta.bene)
        .padding(.vertical, 10)
    }
}

struct NotaFoglio: View {
    let testo: String

    var body: some View {
        Text(testo)
            .font(.system(size: 12.5)).foregroundStyle(Tinta.tenue)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8).padding(.horizontal, 2)
    }
}

struct Conteggio: View {
    let quanti: Int
    let testo: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(Testi.numero(quanti))
                .font(Carattere.serif(21, .title3))
                .foregroundStyle(quanti == 0 ? Tinta.male : Tinta.ink)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(quanti)))
            Text(testo)
                .font(.system(size: 13)).foregroundStyle(Tinta.tenue)
        }
    }
}

extension View {
    func cartaFoglio() -> some View {
        background(Tinta.fondo, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tinta.linea, lineWidth: 0.5))
    }

    func piedeFoglio() -> some View {
        padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider().overlay(Tinta.linea) }
    }
}

struct TastoCasuale: View {
    var lato: CGFloat = 44
    let azione: () -> Void
    @AppStorage("visore.casuale.visto") private var visto = false
    @Environment(\.accessibilityReduceMotion) private var piano
    @State private var giri = 0
    @State private var onda = false

    var body: some View {
        Button {
            giri += 1
            visto = true
            azione()
        } label: {
            Image(systemName: "shuffle")
                .font(.system(size: lato * 0.41, weight: .semibold))
                .foregroundStyle(.white)
                .rotation3DEffect(.degrees(Double(giri) * 360), axis: (x: 0, y: 1, z: 0))
                .animation(piano ? nil : .spring(duration: 0.5, bounce: 0.35), value: giri)
                .frame(width: lato, height: lato)
                .modifier(FondoArancio())
                .overlay {
                    if !visto, !piano {
                        Circle().stroke(Tinta.arancio, lineWidth: 2)
                            .padding(-4)
                            .scaleEffect(onda ? 1.3 : 0.92)
                            .opacity(onda ? 0 : 0.75)
                            .animation(.easeOut(duration: 2.2).repeatForever(autoreverses: false), value: onda)
                            .onAppear { onda = true }
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(Premuto(quanto: 0.88))
        .sensoryFeedback(.impact(weight: .light), trigger: giri)
        .accessibilityLabel("A caso")
        .accessibilityHint("Scegli cosa mescolare e guarda foto e video in ordine sparso")
    }
}

struct FondoArancio: ViewModifier {
    @AppStorage(Vetro.chiave) private var vetro = true

    @ViewBuilder
    func body(content: Content) -> some View {
        if Vetro.vero(vetro) {
            content.vetro(Circle(), tinta: Tinta.arancio, interattivo: true)
        } else {
            content.background {
                Circle().fill(Tinta.arancio)
                    .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                                          startPoint: .top, endPoint: .center)))
                    .shadow(color: Tinta.arancio.opacity(0.45), radius: 8, y: 4)
            }
        }
    }
}

struct TesseraTipo: View {
    let nome: String
    let simbolo: String
    let quanti: Int?
    let acceso: Bool
    let trema: Int
    var stato: String? = nil
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: simbolo)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(acceso ? Tinta.suAccento : Tinta.tenue)
                    .frame(width: 38, height: 38)
                    .background(acceso ? Tinta.accento : Tinta.pozzo,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .rotationEffect(.degrees(acceso ? -6 : 0))
                    .padding(.bottom, 6)
                Text(nome).font(.system(size: 15, weight: .semibold)).foregroundStyle(Tinta.ink)
                Text(stato ?? quanti.map(Testi.numero) ?? " ")
                    .font(.system(size: 12)).foregroundStyle(Tinta.tenue)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(quanti ?? 0)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(acceso ? Tinta.accento.opacity(0.09) : Tinta.fondo,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(acceso ? Tinta.accento.opacity(0.55) : Tinta.linea, lineWidth: acceso ? 1 : 0.5))
            .overlay(alignment: .topTrailing) { Spunta(acceso: acceso).padding(10) }
            .shadow(color: acceso ? Tinta.accento.opacity(0.16) : .clear, radius: 10, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(Premuto(quanto: 0.95))
        .modifier(Trema(volte: trema))
        .modifier(Salta(acceso: acceso))
        .animation(Moto.molla, value: acceso)
        .accessibilityLabel(nome)
        .accessibilityValue(stato ?? quanti.map { Tipi.scatti($0) } ?? "")
        .accessibilityAddTraits(acceso ? .isSelected : [])
    }
}

struct SceltaCasuale: View {
    let pacchetto: Pacchetto
    let vivo: Bool
    let via: (Ricetta) -> Void
    @Environment(\.dismiss) private var chiudi
    @Environment(\.accessibilityReduceMotion) private var piano
    @StateObject private var avvisi = Annunci()
    @State private var ricetta: Ricetta
    @State private var quanti: Int
    @State private var perTipo: [String: Int] = [:]
    @State private var nodi: [Nodo] = []
    @State private var persone: [Persona] = []
    @State private var anni: [Anno] = []
    @State private var tremaTipo: [String: Int] = [:]
    @State private var tremaZero = 0
    @State private var apparso = false
    @State private var luce = false

    init(pacchetto: Pacchetto, iniziale: Ricetta, vivo: Bool = false, via: @escaping (Ricetta) -> Void) {
        self.pacchetto = pacchetto
        self.vivo = vivo
        self.via = via
        _ricetta = State(initialValue: iniziale)
        _quanti = State(initialValue: (try? pacchetto.archivio.quanti(mescola: iniziale.mescola)) ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                testa
                titoletto("Tipo di scatto", ricetta.mescola.generi.count < Mescola.generiTutti.count
                          ? ("Tutti e tre", { tuttiITipi() }) : nil)
                HStack(spacing: 8) {
                    ForEach(Array(Tipi.elenco.enumerated()), id: \.element.id) { i, t in
                        TesseraTipo(nome: t.nome, simbolo: t.simbolo, quanti: perTipo[t.chiave],
                                    acceso: ricetta.mescola.generi.contains(t.chiave),
                                    trema: tremaTipo[t.chiave] ?? 0) { cambiaTipo(t.chiave) }
                            .entra(apparso, i, piano)
                    }
                }
                Text(Tipi.aParole(ricetta.mescola.generi))
                    .font(.system(size: 12.5)).foregroundStyle(Tinta.tenue)
                    .padding(.top, 8).padding(.horizontal, 2)
                    .contentTransition(.opacity)
                    .animation(Moto.passo, value: ricetta.mescola.generi)
                if !nodi.isEmpty { sezioneNodi }
                if !persone.isEmpty { sezionePersone }
                if !anni.isEmpty { sezioneAnni }
                titoletto("Come")
                VStack(spacing: 0) {
                    Interruttore(nome: "Prima i preferiti", nota: "I cuori escono per primi", valore: $ricetta.primaICuori)
                    Divider().overlay(Tinta.linea)
                    Interruttore(nome: "Video con l'audio", nota: "Il suono sale piano, senza spaventare", valore: $ricetta.audio)
                    Divider().overlay(Tinta.linea)
                    Interruttore(nome: "Ricomincia alla fine", nota: "Rimescola e riparte da solo", valore: $ricetta.ricomincia)
                }
                .padding(.horizontal, 14)
                .cartaFoglio()
                titoletto("Ogni foto resta")
                Picker("Ogni foto resta", selection: $ricetta.ritmo) {
                    ForEach([3.0, 5.0, 8.0], id: \.self) { Text("\(Int($0)) secondi").tag($0) }
                }
                .pickerStyle(.segmented)
                NotaFoglio(testo: "Le Live restano almeno 4 secondi, i video quanto durano (fino a 14).")
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) { piede }
        .modifier(ConAnnunci(annunci: avvisi, sopra: 140))
        .sensoryFeedback(.selection, trigger: ricetta.mescola)
        .sensoryFeedback(.warning, trigger: tremaZero)
        .task {
            let a = pacchetto.archivio
            nodi = (try? a.nodi(figliDi: nil)) ?? []
            persone = Array(((try? a.persone()) ?? []).prefix(40))
            anni = (try? a.anni()) ?? []
            conta()
            apparso = true
        }
        .onChange(of: ricetta.mescola) { _, _ in conta() }
    }

    private var testa: some View {
        TestaFoglio(titolo: vivo ? "Cambia la scelta" : "A caso",
                    sotto: vivo ? "La mostra continua con la nuova scelta." : "Scegli cosa mescolare. Senza scelte, tutto.") { chiudi() }
    }

    private var sezioneNodi: some View {
        VStack(alignment: .leading, spacing: 0) {
            titoletto("Nodi", ricetta.mescola.nodi.isEmpty ? ("Tutti", { tuttiINodi() }) : ("Togli tutti", { cambia { $0.nodi = [] } }))
            VStack(spacing: 0) {
                ForEach(Array(nodi.enumerated()), id: \.element.id) { i, n in
                    if i > 0 { Divider().overlay(Tinta.linea).padding(.leading, 68) }
                    rigaNodo(n).entra(apparso, i + 3, piano)
                }
            }
            .cartaFoglio()
        }
    }

    private func rigaNodo(_ n: Nodo) -> some View {
        let on = ricetta.mescola.nodi.contains(n.id)
        return Button {
            cambia { m in if on { m.nodi.remove(n.id) } else { m.nodi.insert(n.id) } }
        } label: {
            HStack(spacing: 12) {
                Copertina(pacchetto: pacchetto, nodo: n, lato: 42)
                    .rotationEffect(.degrees(on ? -4 : 0))
                    .scaleEffect(on ? 1.05 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(n.nome).font(.system(size: 15.5, weight: .medium)).foregroundStyle(Tinta.ink).lineLimit(1)
                    Text(Tipi.scatti(n.quantiColRamo)).font(Carattere.minore).foregroundStyle(Tinta.tenue)
                }
                Spacer(minLength: 8)
                Spunta(acceso: on, lato: 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .animation(Moto.molla, value: on)
        }
        .buttonStyle(Premuto(quanto: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(n.nome)
        .accessibilityValue(Tipi.scatti(n.quantiColRamo))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private var sezionePersone: some View {
        VStack(alignment: .leading, spacing: 0) {
            titoletto("Persone", ricetta.mescola.persone.isEmpty ? nil : ("Togli tutte", { cambia { $0.persone = [] } }))
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(persone) { p in
                        let on = ricetta.mescola.persone.contains(p.id)
                        Button {
                            cambia { m in if on { m.persone.remove(p.id) } else { m.persone.insert(p.id) } }
                        } label: {
                            VStack(spacing: 6) {
                                Volto(pacchetto: pacchetto, persona: p, lato: 56)
                                    .overlay(Circle().stroke(Tinta.accento, lineWidth: 2.5).padding(-5)
                                        .opacity(on ? 1 : 0).scaleEffect(on ? 1 : 0.85))
                                    .scaleEffect(on ? 0.94 : 1)
                                    .padding(5)
                                Text(p.nome)
                                    .font(.system(size: 11.5, weight: on ? .semibold : .regular))
                                    .foregroundStyle(on ? Tinta.ink : Tinta.attenuato)
                                    .lineLimit(1)
                                    .frame(width: 66)
                            }
                            .animation(Moto.molla, value: on)
                        }
                        .buttonStyle(Premuto(quanto: 0.92))
                        .accessibilityLabel(p.nome)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -18)
        }
    }

    private var sezioneAnni: some View {
        VStack(alignment: .leading, spacing: 0) {
            titoletto("Anni", ricetta.mescola.anni.isEmpty ? nil : ("Togli tutti", { cambia { $0.anni = [] } }))
            Fila(spazio: 7) {
                ForEach(anni) { a in
                    let on = ricetta.mescola.anni.contains(a.anno)
                    Button {
                        cambia { m in if on { m.anni.remove(a.anno) } else { m.anni.insert(a.anno) } }
                    } label: {
                        HStack(spacing: 5) {
                            Text(a.anno).monospacedDigit()
                            Text(Testi.numero(a.quanti)).font(.system(size: 11.5)).opacity(0.7).monospacedDigit()
                        }
                        .font(.system(size: 13.5, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Tinta.suAccento : Tinta.ink)
                        .padding(.horizontal, 13)
                        .frame(height: 32)
                        .background(on ? Tinta.accento : Tinta.fondo, in: Capsule())
                        .overlay(Capsule().stroke(on ? Color.clear : Tinta.lineaForte, lineWidth: 0.5))
                        .contentShape(Capsule())
                        .modifier(Salta(acceso: on))
                        .animation(Moto.gesto, value: on)
                    }
                    .buttonStyle(Premuto(quanto: 0.94))
                    .accessibilityLabel("\(a.anno), \(Tipi.scatti(a.quanti))")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var piede: some View {
        VStack(spacing: 9) {
            Conteggio(quanti: quanti, testo: quanti == 1 ? "scatto da mescolare" : "scatti da mescolare")
            .modifier(Trema(volte: tremaZero))
            .animation(Moto.passo, value: quanti)
            .accessibilityElement(children: .combine)
            Button(action: parti) {
                Label(vivo ? "Continua così" : quanti == 0 ? "Nessuno scatto" : "Mescola e guarda", systemImage: "shuffle")
            }
            .buttonStyle(TastoPieno())
            .overlay { lama }
            .shadow(color: Tinta.accento.opacity(quanti == 0 ? 0 : 0.32), radius: 12, y: 8)
            .disabled(quanti == 0)
        }
        .piedeFoglio()
    }

    private var lama: some View {
        GeometryReader { g in
            LinearGradient(colors: [.clear, .white.opacity(0.32), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: g.size.width * 0.45)
                .offset(x: luce ? g.size.width * 1.1 : -g.size.width * 0.6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .allowsHitTesting(false)
    }

    private func titoletto(_ testo: String, _ azione: (String, () -> Void)? = nil) -> some View {
        TitolettoFoglio(testo: testo, azione: azione)
    }

    private func cambia(_ fai: (inout Mescola) -> Void) {
        var m = ricetta.mescola
        fai(&m)
        withAnimation(Moto.molla) { ricetta.mescola = m }
    }

    private func cambiaTipo(_ g: String) {
        if ricetta.mescola.generi.contains(g), ricetta.mescola.generi.count == 1 {
            tremaTipo[g, default: 0] += 1
            avvisi.di("Tieni acceso almeno un tipo", simbolo: "exclamationmark.circle")
            return
        }
        cambia { m in if m.generi.contains(g) { m.generi.remove(g) } else { m.generi.insert(g) } }
    }

    private func tuttiITipi() {
        cambia { $0.generi = Set(Mescola.generiTutti) }
    }

    private func tuttiINodi() {
        cambia { m in m.nodi = Set(nodi.map(\.id)) }
    }

    private func conta() {
        let a = pacchetto.archivio
        let n = (try? a.quanti(mescola: ricetta.mescola)) ?? 0
        let t = (try? a.quantiPerGenere(mescola: ricetta.mescola)) ?? [:]
        if n == 0, quanti > 0 { tremaZero += 1 }
        withAnimation(Moto.passo) {
            quanti = n
            perTipo = t
        }
    }

    private func parti() {
        guard quanti > 0 else { return }
        var senza = Transaction()
        senza.disablesAnimations = true
        withTransaction(senza) { luce = false }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: piano ? 0.01 : 0.6)) { luce = true }
        }
        let scelta = ricetta
        DispatchQueue.main.asyncAfter(deadline: .now() + (piano ? 0 : 0.18)) {
            via(scelta)
            chiudi()
        }
    }
}

extension View {
    func entra(_ apparso: Bool, _ i: Int, _ piano: Bool) -> some View {
        opacity(apparso ? 1 : 0)
            .offset(y: apparso || piano ? 0 : 12)
            .animation(piano ? .linear(duration: 0.01) : Moto.scena.delay(Double(min(i, 12)) * 0.035), value: apparso)
    }
}

struct QuadroCasuale: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    let durata: Double
    let audio: Bool
    let fermo: Bool
    @StateObject private var movimento = Movimento()
    @State private var immagine: UIImage?
    @State private var grande = false
    @State private var vai = false
    @State private var rotta = false
    @Environment(\.accessibilityReduceMotion) private var piano

    var body: some View {
        ZStack {
            if let immagine {
                Image(uiImage: immagine)
                    .resizable()
                    .allowedDynamicRange(grande ? .high : .standard)
                    .scaledToFit()
            }
            if scatto.live || scatto.video {
                StratoVideo(lettore: movimento.lettore)
                    .opacity(movimento.inCorso ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(vai ? 1.12 : 1.02)
        .offset(vai ? spinta : .zero)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .center) {
            if rotta || movimento.rotto {
                Text(scatto.video ? "Questo video non si apre qui." : "Questa foto non si apre qui.")
                    .font(.system(size: 13)).foregroundStyle(Tinta.carta)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .vetro(Capsule(), ripiego: .ultraThinMaterial, bordo: false)
                    .environment(\.colorScheme, .dark)
            }
        }
        .clipped()
        .task(id: scatto.id) { await carica() }
        .onChange(of: audio) { _, a in alza(a) }
        .onChange(of: fermo) { _, f in
            guard movimento.inCorso else { return }
            if f { movimento.lettore.pause() } else { movimento.lettore.play() }
        }
        .onDisappear { movimento.chiudi() }
    }

    private var spinta: CGSize {
        CGSize(width: (Double(scatto.id % 7) - 3) * 7, height: (Double(scatto.id % 5) - 2) * 6)
    }

    private func carica() async {
        let mini = scatto.mini ?? scatto.posto
        immagine = Miniature.tutte.pronta(mini)
        if immagine == nil { immagine = await Miniature.tutte.carica(pacchetto, mini, lato: 600) }
        if !piano, !scatto.video {
            withAnimation(.linear(duration: durata + 1.2)) { vai = true }
        }
        if scatto.video {
            await movimento.prepara(pacchetto: pacchetto, posto: scatto.posto)
            guard !Task.isCancelled, movimento.pronto else { return }
            movimento.lettore.volume = 0
            movimento.muto = !audio
            movimento.unGiro()
            alza(audio)
            return
        }
        if let g = await Originali.tutti.carica(pacchetto, scatto.posto) {
            immagine = g
            grande = true
        } else {
            rotta = immagine == nil
        }
        guard scatto.live, let m = scatto.postoMovimento, !Task.isCancelled else { return }
        await movimento.prepara(pacchetto: pacchetto, posto: m)
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled, movimento.pronto, !fermo else { return }
        movimento.lettore.volume = 0
        movimento.muto = !audio
        movimento.unGiro()
        alza(audio)
    }

    private func alza(_ acceso: Bool) {
        movimento.muto = !acceso
        guard acceso else { return }
        let lettore = movimento.lettore
        lettore.volume = 0
        Task { @MainActor in
            for passo in 1...12 {
                try? await Task.sleep(for: .milliseconds(100))
                lettore.volume = Float(passo) / 12
            }
        }
    }
}

struct MostraCasuale: View {
    let pacchetto: Pacchetto
    @State private var ricetta: Ricetta
    @EnvironmentObject var cassetto: Cassetto
    @Environment(\.dismiss) private var chiudi
    @Environment(\.accessibilityReduceMotion) private var piano
    @StateObject private var avvisi = Annunci()
    @State private var pescati: [Pescato] = []
    @State private var coda: [Int64] = []
    @State private var scatti: [Int64: Scatto] = [:]
    @State private var dettagli: [Int64: Dettagli] = [:]
    @State private var qui = 0
    @State private var trascorso: Double = 0
    @State private var fermo = false
    @State private var nudo = false
    @State private var audio: Bool
    @State private var colpi = 0
    @State private var cambiando = false
    @State private var dado = 0
    @State private var giro = 0
    @State private var giu: CGFloat = 0
    @State private var verticale: Bool?
    @State private var ultimoTocco: Date?
    @State private var inizio: Date?
    @State private var attesa: Task<Void, Never>?
    @State private var tieni: Task<Void, Never>?

    init(pacchetto: Pacchetto, ricetta: Ricetta) {
        self.pacchetto = pacchetto
        _ricetta = State(initialValue: ricetta)
        _audio = State(initialValue: ricetta.audio)
    }

    private var attuale: Scatto? {
        coda.indices.contains(qui) ? scatti[coda[qui]] : nil
    }

    var body: some View {
        GeometryReader { g in
            ZStack {
                Color.black.ignoresSafeArea()
                if let s = attuale {
                    QuadroCasuale(pacchetto: pacchetto, scatto: s, durata: durata(s), audio: audio,
                                  fermo: fermo || cambiando)
                        .id(s.id)
                        .transition(.opacity)
                        .ignoresSafeArea()
                }
                ombre
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(dito(g.size.width))
                    .ignoresSafeArea()
                comandi
                    .opacity(nudo || fermo ? 0 : 1)
                    .animation(Moto.passo, value: nudo || fermo)
                if fermo {
                    Text("In pausa · lascia per ripartire")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Tinta.carta)
                        .padding(.horizontal, 12).frame(height: 30)
                        .vetro(Capsule(), ripiego: .ultraThinMaterial, bordo: false)
                        .environment(\.colorScheme, .dark)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 24)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
                CuoreGrande(colpi: colpi)
                if !piano { dadoArancio }
            }
            .offset(y: giu)
            .scaleEffect(1 - min(0.12, giu / 1600))
        }
        .background(Color.black.opacity(1 - min(0.6, Double(giu) / 500)).ignoresSafeArea())
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .modifier(ConAnnunci(annunci: avvisi, sopra: 150))
        .sensoryFeedback(.impact(weight: .light), trigger: colpi)
        .sensoryFeedback(.impact(weight: .medium), trigger: fermo)
        .sensoryFeedback(.selection, trigger: giro)
        .animation(Moto.passo, value: fermo)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            attesa?.cancel()
            tieni?.cancel()
        }
        .task {
            pesca(Mescola.rimescola((try? pacchetto.archivio.pescati(mescola: ricetta.mescola)) ?? [], seme: seme()))
            dado += 1
            var prima = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                let ora = Date()
                scorri(ora.timeIntervalSince(prima))
                prima = ora
            }
        }
        .sheet(isPresented: $cambiando) {
            SceltaCasuale(pacchetto: pacchetto, iniziale: ricetta, vivo: true) { nuova in cambia(nuova) }
                .foglioStile()
        }
    }

    private var ombre: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 170)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
        }
        .ignoresSafeArea()
        .opacity(nudo || fermo ? 0 : 1)
        .animation(Moto.passo, value: nudo || fermo)
        .allowsHitTesting(false)
    }

    private var comandi: some View {
        VStack(spacing: 10) {
            barre
            HStack(spacing: 8) {
                Vetrino(simbolo: "xmark", etichetta: "Chiudi") { chiudi() }
                Spacer(minLength: 4)
                if !coda.isEmpty {
                    Text("\(Testi.numero(qui + 1)) di \(Testi.numero(coda.count))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Tinta.carta.opacity(0.85))
                        .contentTransition(.numericText(value: Double(qui)))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Vetrino(simbolo: audio ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        etichetta: audio ? "Togli l'audio" : "Accendi l'audio", acceso: audio) {
                    audio.toggle()
                    avvisi.di(audio ? "Audio dei video acceso" : "Audio spento",
                              simbolo: audio ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                Vetrino(simbolo: "slider.horizontal.3", etichetta: "Cambia la scelta") { cambiando = true }
                Button { rimescola("Rimescolato · " + Tipi.scatti(coda.count)) } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotation3DEffect(.degrees(Double(giro) * 360), axis: (x: 0, y: 1, z: 0))
                        .animation(piano ? nil : .spring(duration: 0.5, bounce: 0.35), value: giro)
                        .frame(width: 44, height: 44)
                        .background(Tinta.arancio, in: Circle())
                        .shadow(color: Tinta.arancio.opacity(0.5), radius: 8, y: 4)
                        .contentShape(Circle())
                }
                .buttonStyle(Premuto(quanto: 0.88))
                .accessibilityLabel("Rimescola")
            }
            Spacer(minLength: 0)
            if let s = attuale { didascalia(s) }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    private var barre: some View {
        let da = qui / 10 * 10
        let fino = min(coda.count, da + 10)
        return HStack(spacing: 4) {
            ForEach(Array(da..<max(da, fino)), id: \.self) { k in
                GeometryReader { g in
                    Capsule().fill(.white.opacity(0.3))
                        .overlay(alignment: .leading) {
                            Capsule().fill(.white).frame(width: g.size.width * riempito(k))
                        }
                }
                .frame(height: 2.5)
            }
        }
        .frame(height: 2.5)
        .padding(.horizontal, 2)
        .accessibilityHidden(true)
    }

    private func didascalia(_ s: Scatto) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Testi.giorno(s.giorno))
                .font(Carattere.serif(24, .title2))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 10)
            HStack(spacing: 6) {
                Image(systemName: s.live ? "livephoto" : s.video ? "video" : "mappin")
                    .font(.system(size: 12, weight: .semibold))
                Text(riga(s)).lineLimit(1)
            }
            .font(.system(size: 13.5))
            .foregroundStyle(.white.opacity(0.85))
            if let persone = dettagli[s.id]?.persone, !persone.isEmpty {
                Fila(spazio: 6) {
                    ForEach(persone.prefix(6)) { p in
                        HStack(spacing: 6) {
                            Volto(pacchetto: pacchetto, persona: p, lato: 22)
                            Text(p.nome).font(.system(size: 12)).foregroundStyle(Tinta.carta).lineLimit(1)
                        }
                        .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                        .vetro(Capsule(), ripiego: .ultraThinMaterial, bordo: false)
                        .environment(\.colorScheme, .dark)
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.bottom, 22)
        .id(s.id)
        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private var dadoArancio: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Tinta.arancio)
            .frame(width: 96, height: 96)
            .overlay(Image(systemName: "shuffle").font(.system(size: 40, weight: .semibold)).foregroundStyle(.white))
            .shadow(color: .black.opacity(0.5), radius: 24, y: 14)
            .phaseAnimator([0, 1, 2, 3], trigger: dado) { v, fase in
                v.scaleEffect(fase == 0 ? 0.3 : fase == 1 ? 1.1 : fase == 2 ? 1 : 2.2)
                    .rotationEffect(.degrees(fase == 0 ? -120 : fase == 1 ? 18 : 0))
                    .opacity(fase == 1 || fase == 2 ? 1 : 0)
            } animation: { fase in
                switch fase {
                case 1: return Animation.spring(duration: 0.32, bounce: 0.4)
                case 2: return Animation.spring(duration: 0.2)
                case 3: return Animation.easeIn(duration: 0.28).delay(0.08)
                default: return Animation.easeOut(duration: 0.01)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func riga(_ s: Scatto) -> String {
        var pezzi: [String] = []
        if let l = s.luogo, !l.isEmpty { pezzi.append(l) }
        if let n = dettagli[s.id]?.nodi.first { pezzi.append(n.nome) }
        if s.live { pezzi.append("Live") }
        if s.video { pezzi.append(Testi.durata(s.durataMs)) }
        return pezzi.isEmpty ? "A caso" : pezzi.joined(separator: " · ")
    }

    private func durata(_ s: Scatto) -> Double {
        if s.video { return min(max(Double(s.durataMs ?? 8000) / 1000, 3), 14) }
        return s.live ? max(ricetta.ritmo, 4) : ricetta.ritmo
    }

    private func riempito(_ k: Int) -> CGFloat {
        if k < qui { return 1 }
        guard k == qui, let s = attuale else { return 0 }
        return CGFloat(min(1, trascorso / durata(s)))
    }

    private func seme() -> UInt64 { UInt64.random(in: 1...UInt64.max) }

    private func pesca(_ tutti: [Pescato]) {
        pescati = tutti
        var ordine = tutti
        if ricetta.primaICuori {
            let cuori = cassetto.cuori
            ordine = tutti.filter { cuori.contains($0.impronta) } + tutti.filter { !cuori.contains($0.impronta) }
        }
        coda = ordine.map(\.id)
        scatti = [:]
        qui = 0
        trascorso = 0
        carica(intorno: 0)
        if coda.isEmpty {
            avvisi.di("Nessuno scatto da mostrare", simbolo: "exclamationmark.circle")
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.4))
                chiudi()
            }
        }
    }

    private func carica(intorno i: Int) {
        guard !coda.isEmpty else { return }
        let fino = min(coda.count, i + 30)
        let mancano = coda[max(0, i - 1)..<fino].filter { scatti[$0] == nil }
        if !mancano.isEmpty, let nuovi = try? pacchetto.archivio.scatti(numeri: Array(mancano)) {
            for s in nuovi { scatti[s.id] = s }
        }
        for k in [i, i + 1] where coda.indices.contains(k) {
            let id = coda[k]
            if dettagli[id] == nil, let d = try? pacchetto.archivio.dettagli(id) { dettagli[id] = d }
        }
        if coda.indices.contains(i + 1), let s = scatti[coda[i + 1]], !s.video {
            let p = pacchetto
            Task { _ = await Originali.tutti.carica(p, s.posto) }
        }
    }

    private func scorri(_ dt: Double) {
        guard !fermo, !cambiando, giu == 0, let s = attuale else { return }
        trascorso += dt
        if trascorso >= durata(s) { vai(1) }
    }

    private func vai(_ d: Int) {
        let n = qui + d
        if n >= coda.count {
            if ricetta.ricomincia, !coda.isEmpty {
                rimescola("Rimescolato, si riparte")
            } else {
                chiudi()
            }
            return
        }
        trascorso = 0
        guard n >= 0 else { return }
        carica(intorno: n)
        withAnimation(.easeInOut(duration: piano ? 0.2 : 0.8)) { qui = n }
    }

    private func rimescola(_ annuncio: String) {
        giro += 1
        dado += 1
        let nuovi = Mescola.rimescola(pescati, seme: seme())
        withAnimation(.easeInOut(duration: piano ? 0.2 : 0.8)) { pesca(nuovi) }
        avvisi.di(annuncio, simbolo: "shuffle")
    }

    private func cambia(_ nuova: Ricetta) {
        ricetta = nuova
        audio = nuova.audio
        let nuovi = Mescola.rimescola((try? pacchetto.archivio.pescati(mescola: nuova.mescola)) ?? [], seme: seme())
        dado += 1
        withAnimation(.easeInOut(duration: piano ? 0.2 : 0.8)) { pesca(nuovi) }
        if !coda.isEmpty { avvisi.di("Nuova scelta · " + Tipi.scatti(coda.count), simbolo: "shuffle") }
    }

    private func cuore() {
        if let s = attuale, !cassetto.haIlCuore(s) {
            _ = cassetto.cuore([s.impronta], acceso: true)
        }
        colpi += 1
        avvisi.di("Tra i preferiti", simbolo: "heart.fill")
    }

    private func dito(_ largo: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                if inizio == nil {
                    inizio = v.time
                    tieni?.cancel()
                    tieni = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.26))
                        guard !Task.isCancelled else { return }
                        fermo = true
                    }
                }
                let t = v.translation
                if verticale == nil, max(abs(t.width), abs(t.height)) > 10, !fermo {
                    tieni?.cancel()
                    verticale = abs(t.height) > abs(t.width)
                }
                if verticale == true { giu = max(0, t.height) }
            }
            .onEnded { v in
                tieni?.cancel()
                tieni = nil
                let durataTocco = v.time.timeIntervalSince(inizio ?? v.time)
                let direzione = verticale
                inizio = nil
                verticale = nil
                if fermo {
                    fermo = false
                    return
                }
                if direzione == true {
                    if giu > Gesti.chiudeDopo || v.velocity.height > Gesti.chiudeVeloce {
                        chiudi()
                    } else {
                        withAnimation(Moto.molla) { giu = 0 }
                    }
                    return
                }
                if direzione == false {
                    if abs(v.translation.width) > 50 { vai(v.translation.width < 0 ? 1 : -1) }
                    return
                }
                guard durataTocco < Gesti.tocco else { return }
                if let prima = ultimoTocco, v.time.timeIntervalSince(prima) < Gesti.doppio {
                    ultimoTocco = nil
                    attesa?.cancel()
                    cuore()
                    return
                }
                ultimoTocco = v.time
                let x = v.location.x / max(largo, 1)
                attesa?.cancel()
                attesa = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Gesti.doppio))
                    guard !Task.isCancelled else { return }
                    ultimoTocco = nil
                    if x < 0.34 {
                        vai(-1)
                    } else if x > 0.66 {
                        vai(1)
                    } else {
                        withAnimation(Moto.passo) { nudo.toggle() }
                    }
                }
            }
    }
}
