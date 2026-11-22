import SwiftUI
import VisoreKit

private struct ChiavePremuto: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var premuto: Bool {
        get { self[ChiavePremuto.self] }
        set { self[ChiavePremuto.self] = newValue }
    }
}

struct PremibileVivo: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.premuto, configuration.isPressed)
            .background(configuration.isPressed ? Tinta.superficieAlta : Color.clear)
            .animation(Moto.gesto, value: configuration.isPressed)
    }
}

struct PremutoVivo: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.premuto, configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Moto.gesto, value: configuration.isPressed)
    }
}

struct Entra: ViewModifier {
    let indice: Int
    @State private var dentro = false

    func body(content: Content) -> some View {
        content
            .opacity(dentro ? 1 : 0)
            .offset(y: dentro ? 0 : 10)
            .onAppear {
                guard !dentro else { return }
                withAnimation(Moto.scena.delay(Double(min(indice, 12)) * 0.03)) { dentro = true }
            }
    }
}

extension View {
    func entra(_ indice: Int) -> some View {
        modifier(Entra(indice: indice))
    }
}

struct Miniatura: View {
    let pacchetto: Pacchetto
    let scatto: Scatto?
    let lato: CGFloat
    @State private var immagine: UIImage?
    @Environment(\.displayScale) private var scala

    var body: some View {
        Color.clear
            .overlay {
                if let immagine {
                    Image(uiImage: immagine).resizable().scaledToFill()
                        .transition(.opacity)
                } else if scatto == nil {
                    Tinta.pozzo
                } else {
                    Luccichio()
                }
            }
            .clipped()
            .task(id: scatto?.id) {
                guard let scatto else { return }
                let posto = scatto.mini ?? scatto.posto
                if let pronta = Miniature.tutte.pronta(posto) {
                    immagine = pronta
                    return
                }
                let caricata = await Miniature.tutte.carica(pacchetto, posto, lato: lato * scala)
                withAnimation(Moto.passo) { immagine = caricata }
            }
    }
}

struct Mosaico: View {
    let pacchetto: Pacchetto
    let filtro: Filtro
    var lato: CGFloat = 64
    @State private var scatti: [Scatto] = []
    @Environment(\.premuto) private var premuto

    var body: some View {
        let spazio: CGFloat = premuto ? 4 : 2
        let pezzo = (lato - spazio) / 2
        VStack(spacing: spazio) {
            HStack(spacing: spazio) {
                quadro(0, pezzo)
                quadro(1, pezzo)
            }
            HStack(spacing: spazio) {
                quadro(2, pezzo)
                quadro(3, pezzo)
            }
        }
        .frame(width: lato, height: lato)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .rotationEffect(.degrees(premuto ? -3 : 0))
        .scaleEffect(premuto ? 1.05 : 1)
        .animation(Moto.molla, value: premuto)
        .accessibilityHidden(true)
        .task(id: filtro) {
            if scatti.isEmpty { scatti = (try? pacchetto.archivio.copertine(filtro: filtro)) ?? [] }
        }
    }

    private func quadro(_ i: Int, _ pezzo: CGFloat) -> some View {
        Miniatura(pacchetto: pacchetto, scatto: i < scatti.count ? scatti[i] : nil, lato: pezzo)
            .frame(width: pezzo, height: pezzo)
    }
}

struct EroeNodo: View {
    let pacchetto: Pacchetto
    let scatti: [Scatto]

    var body: some View {
        GeometryReader { g in
            let destra = scatti.count > 1 ? floor((g.size.width - 3) / 3) : 0
            let alto = g.size.height
            HStack(spacing: 3) {
                Miniatura(pacchetto: pacchetto, scatto: scatti.first, lato: 420)
                    .frame(width: g.size.width - (destra > 0 ? destra + 3 : 0), height: alto)
                if destra > 0 {
                    VStack(spacing: 3) {
                        Miniatura(pacchetto: pacchetto, scatto: scatti[1], lato: 200)
                            .frame(width: destra, height: (alto - 3) / 2)
                        Miniatura(pacchetto: pacchetto, scatto: scatti.count > 2 ? scatti[2] : nil, lato: 200)
                            .frame(width: destra, height: (alto - 3) / 2)
                    }
                }
            }
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct Numeri: View {
    let voci: [(String, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(voci.enumerated()), id: \.offset) { i, voce in
                if i > 0 { Rectangle().fill(Tinta.linea).frame(width: 0.5) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(voce.0)
                        .font(Carattere.serif(20, .title3))
                        .foregroundStyle(Tinta.ink)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    Text(voce.1).font(.system(size: 11.5)).foregroundStyle(Tinta.tenue).lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Tinta.superficie, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tinta.linea, lineWidth: 0.5))
    }
}

struct Titoletto: View {
    let testo: String
    var nota: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(testo).etichettaMaiuscola()
            Spacer(minLength: 8)
            if let nota {
                Text(nota).font(.system(size: 12)).foregroundStyle(Tinta.tenue)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }
}

struct AnniABarre: View {
    let anni: [Anno]
    let scelto: String?
    let tocca: (String) -> Void
    @State private var cresciute = false

    var body: some View {
        let massimo = max(1, anni.map(\.quanti).max() ?? 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(anni.enumerated()), id: \.element.id) { i, a in
                    Button {
                        tocca(a.anno)
                    } label: {
                        UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 1,
                                               bottomTrailingRadius: 1, topTrailingRadius: 3, style: .continuous)
                            .fill(scelto == a.anno ? Tinta.accento : Tinta.accento.opacity(0.45))
                            .frame(height: max(4, 54 * CGFloat(a.quanti) / CGFloat(massimo)))
                            .scaleEffect(x: 1, y: cresciute ? 1 : 0, anchor: .bottom)
                            .animation(Moto.scena.delay(Double(i) * 0.02), value: cresciute)
                            .frame(maxWidth: .infinity, maxHeight: 54, alignment: .bottom)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(Premuto(quanto: 0.94))
                    .accessibilityLabel("\(a.anno), \(Testi.foto(a.quanti))")
                }
            }
            .frame(height: 54)
            HStack {
                Text(anni.first?.anno ?? "")
                Spacer()
                Text(anni.last?.anno ?? "")
            }
            .font(.system(size: 11))
            .foregroundStyle(Tinta.tenue)
            .monospacedDigit()
            Text(riga)
                .font(.system(size: 13))
                .foregroundStyle(Tinta.attenuato)
                .contentTransition(.opacity)
                .animation(Moto.passo, value: scelto)
        }
        .carta(12)
        .onAppear { cresciute = true }
        .sensoryFeedback(.selection, trigger: scelto)
    }

    private var riga: String {
        guard let scelto, let a = anni.first(where: { $0.anno == scelto }) else {
            return "Tocca un anno per vedere solo le sue foto"
        }
        return "\(a.anno) · \(Testi.foto(a.quanti)) · tocca di nuovo per toglierlo"
    }
}

struct PilloleLuoghi: View {
    let luoghi: [Luogo]
    let scelto: Int64?
    let tocca: (Int64) -> Void

    var body: some View {
        Fila(spazio: 6) {
            ForEach(Array(luoghi.enumerated()), id: \.element.id) { i, l in
                Button {
                    tocca(l.id)
                } label: {
                    Pillola(testo: l.nome, simbolo: "mappin", scelta: scelto == l.id)
                }
                .buttonStyle(Premuto())
                .entra(i)
            }
        }
        .sensoryFeedback(.selection, trigger: scelto)
    }
}

struct FiltriAttivi: View {
    @Binding var anno: String?
    @Binding var luogo: Int64?
    let luoghi: [Luogo]

    var body: some View {
        if anno != nil || luogo != nil {
            Fila(spazio: 6) {
                if let anno {
                    Pillola(testo: anno, scelta: true, togli: { withAnimation(Moto.passo) { self.anno = nil } })
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                if let luogo {
                    Pillola(testo: luoghi.first(where: { $0.id == luogo })?.nome ?? "Luogo", simbolo: "mappin",
                            scelta: true, togli: { withAnimation(Moto.passo) { self.luogo = nil } })
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .padding(.top, 4)
        }
    }
}

struct FilaVolti: View {
    let pacchetto: Pacchetto
    let compagni: [Compagno]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(Array(compagni.enumerated()), id: \.element.id) { i, c in
                    NavigationLink(value: c.persona) {
                        VStack(spacing: 5) {
                            VoltoVivo(pacchetto: pacchetto, persona: c.persona, lato: 56)
                            Text(c.persona.nome).font(.system(size: 12)).foregroundStyle(Tinta.ink)
                                .lineLimit(2).multilineTextAlignment(.center)
                            Text(Testi.numero(c.quante)).font(.system(size: 11)).foregroundStyle(Tinta.tenue)
                                .monospacedDigit()
                        }
                        .frame(width: 70)
                    }
                    .buttonStyle(PremutoVivo())
                    .entra(i)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }
}

struct VoltoVivo: View {
    let pacchetto: Pacchetto
    let persona: Persona
    let lato: CGFloat
    @Environment(\.premuto) private var premuto

    var body: some View {
        Volto(pacchetto: pacchetto, persona: persona, lato: lato)
            .padding(3)
            .overlay(Circle().stroke(Tinta.accento, lineWidth: 2.5).opacity(premuto ? 1 : 0))
            .animation(Moto.gesto, value: premuto)
    }
}

struct TondoConAnello: View {
    let pacchetto: Pacchetto
    let persona: Persona
    let quota: Double
    let pieno: Bool
    @Environment(\.premuto) private var premuto

    var body: some View {
        ZStack {
            Circle().stroke(Tinta.linea, lineWidth: 2.5).padding(1.5)
            Circle()
                .trim(from: 0, to: pieno ? max(0.03, min(1, quota)) : 0)
                .stroke(Tinta.accento, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(1.5)
            Circle().stroke(Tinta.accento, lineWidth: 3).padding(1.5).opacity(premuto ? 1 : 0)
            Volto(pacchetto: pacchetto, persona: persona, lato: 52)
                .scaleEffect(premuto ? 0.92 : 1)
        }
        .frame(width: 64, height: 64)
        .animation(Moto.gesto, value: premuto)
    }
}

struct EroePersona: View {
    let pacchetto: Pacchetto
    let persona: Persona
    @State private var dentro = false
    @State private var battito = false

    var body: some View {
        Volto(pacchetto: pacchetto, persona: persona, lato: 112)
            .padding(4)
            .overlay(Circle().stroke(Tinta.lineaForte, lineWidth: 1))
            .background(
                Circle()
                    .stroke(Tinta.accento, lineWidth: 2)
                    .scaleEffect(battito ? 1.3 : 1)
                    .opacity(battito ? 0 : 0.9)
            )
            .scaleEffect(dentro ? 1 : 0.6)
            .opacity(dentro ? 1 : 0)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
            .onAppear {
                guard !dentro else { return }
                withAnimation(Moto.molla) { dentro = true }
                withAnimation(.easeOut(duration: 1.8).delay(0.7)) { battito = true }
            }
    }
}

struct DueVolti: View {
    let pacchetto: Pacchetto
    let prima: Persona
    let seconda: Persona
    @State private var vicini = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Volto(pacchetto: pacchetto, persona: prima, lato: 32)
                .offset(x: vicini ? 0 : -3, y: vicini ? 0 : -3)
            Volto(pacchetto: pacchetto, persona: seconda, lato: 32)
                .overlay(Circle().stroke(Tinta.superficie, lineWidth: 2))
                .offset(x: vicini ? 12 : 15, y: vicini ? 12 : 15)
        }
        .frame(width: 44, height: 44, alignment: .topLeading)
        .onAppear { withAnimation(Moto.molla.delay(0.15)) { vicini = true } }
    }
}

struct IndiceLettere: View {
    let lettere: [String]
    let scegli: (String) -> Void
    @State private var attuale: String?

    var body: some View {
        VStack(spacing: 1) {
            ForEach(lettere, id: \.self) { l in
                Text(l)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tinta.accento)
                    .frame(width: 22, height: 16)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    guard !lettere.isEmpty else { return }
                    let i = Int(floor((v.location.y - 6) / 17))
                    let l = lettere[min(max(i, 0), lettere.count - 1)]
                    if l != attuale {
                        attuale = l
                        scegli(l)
                    }
                }
                .onEnded { _ in attuale = nil }
        )
        .overlay(alignment: .leading) {
            if let attuale {
                Text(attuale)
                    .font(Carattere.serif(28, .title))
                    .foregroundStyle(Tinta.suAccento)
                    .frame(width: 56, height: 56)
                    .background(Tinta.accento, in: Circle())
                    .shadow(color: Tinta.ombra, radius: 10, y: 4)
                    .offset(x: -72)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(Moto.molla, value: attuale)
        .sensoryFeedback(.selection, trigger: attuale)
        .accessibilityHidden(true)
    }
}
