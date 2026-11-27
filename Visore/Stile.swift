import SwiftUI
import UIKit

enum Tinta {
    private static func due(_ chiaro: UInt32, _ scuro: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? colore(scuro) : colore(chiaro) })
    }

    private static func colore(_ esa: UInt32) -> UIColor {
        UIColor(red: CGFloat((esa >> 16) & 0xFF) / 255, green: CGFloat((esa >> 8) & 0xFF) / 255,
                blue: CGFloat(esa & 0xFF) / 255, alpha: 1)
    }

    static let fondo = due(0xFAF9F5, 0x262624)
    static let laterale = due(0xF3F1EA, 0x1F1E1D)
    static let superficie = due(0xFFFFFF, 0x30302E)
    static let superficieAlta = due(0xF0EEE6, 0x3A3936)
    static let pozzo = due(0xEDEAE0, 0x1B1B19)
    static let linea = due(0xE3DFD3, 0x3E3D39)
    static let lineaForte = due(0xC9C4B5, 0x55534D)
    static let ink = due(0x141413, 0xF5F4EE)
    static let attenuato = due(0x3D3D3A, 0xC2C0B6)
    static let tenue = due(0x6B6962, 0xA6A49A)
    static let accento = due(0xC2603F, 0xD97757)
    static let suAccento = due(0xFFFFFF, 0x1F1E1D)
    static let bene = due(0x4F7F4A, 0x8FB58A)
    static let attenzione = due(0x9A6B14, 0xD9A957)
    static let male = due(0xB0473A, 0xD9776A)
    static let alone = accento.opacity(0.26)
    static let ombra = Color.black.opacity(0.22)

    static let notte = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x13 / 255)
    static let carta = Color(red: 0xF5 / 255, green: 0xF4 / 255, blue: 0xEE / 255)
    static let grigioNotte = Color(red: 0xC2 / 255, green: 0xC0 / 255, blue: 0xB6 / 255)
    static let arancio = Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)
}

enum Carattere {
    static let nome = "SourceSerif4Roman-Regular"
    static let presente = UIFont(name: nome, size: 12) != nil

    static func serif(_ lato: CGFloat, _ come: Font.TextStyle = .body) -> Font {
        presente ? .custom(nome, size: lato, relativeTo: come) : .system(size: lato, design: .serif)
    }

    static let grande = serif(34, .largeTitle)
    static let titolo = serif(30, .largeTitle)
    static let titoletto = serif(21, .title2)
    static let giorno = serif(18, .title3)
    static let piccolo = serif(16, .headline)
    static let comando = Font.system(size: 14, weight: .medium)
    static let minore = Font.system(size: 12.5)
    static let minimo = Font.system(size: 11, weight: .medium)
}

enum Moto {
    static let gesto = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.18)
    static let passo = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.26)
    static let scena = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.36)
    static let molla = Animation.spring(duration: 0.34, bounce: 0.28)
    static let foglio = Animation.spring(duration: 0.42, bounce: 0.12)
}

struct Premuto: ButtonStyle {
    var quanto: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? quanto : 1)
            .animation(Moto.gesto, value: configuration.isPressed)
    }
}

struct TastoPieno: ButtonStyle {
    var colore: Color = Tinta.accento
    @Environment(\.isEnabled) private var acceso

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Tinta.suAccento)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(colore.opacity(acceso ? 1 : 0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Moto.gesto, value: configuration.isPressed)
    }
}

struct TastoBordo: ButtonStyle {
    @Environment(\.isEnabled) private var acceso

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Tinta.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(configuration.isPressed ? Tinta.superficieAlta : Color.clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tinta.lineaForte, lineWidth: 0.5))
            .opacity(acceso ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Moto.gesto, value: configuration.isPressed)
    }
}

struct Pillola: View {
    let testo: String
    var simbolo: String? = nil
    var scelta = false
    var togli: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let simbolo { Image(systemName: simbolo).font(.system(size: 12, weight: .semibold)) }
            Text(testo).lineLimit(1)
            if let togli {
                Button(action: togli) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18)
                        .contentShape(Circle())
                }
                .buttonStyle(Premuto(quanto: 0.85))
                .accessibilityLabel("Togli \(testo)")
            }
        }
        .font(.system(size: 13.5, weight: scelta ? .semibold : .regular))
        .foregroundStyle(Tinta.ink)
        .padding(.leading, 13)
        .padding(.trailing, togli == nil ? 13 : 7)
        .frame(height: 32)
        .background(scelta ? Tinta.alone : Color.clear, in: Capsule())
        .overlay(Capsule().stroke(scelta ? Color.clear : Tinta.lineaForte, lineWidth: 0.5))
        .contentShape(Capsule())
        .fixedSize()
        .animation(Moto.gesto, value: scelta)
    }
}

struct Tondo: View {
    let simbolo: String
    let etichetta: String
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            FacciaTondo(simbolo: simbolo)
        }
        .buttonStyle(Premuto(quanto: 0.9))
        .accessibilityLabel(etichetta)
    }
}

struct Vetrino: View {
    let simbolo: String
    let etichetta: String
    var acceso = false
    let azione: () -> Void

    var body: some View {
        Button(action: azione) {
            Image(systemName: simbolo)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(acceso ? Tinta.arancio : Tinta.carta)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: acceso)
                .frame(width: 44, height: 44)
                .vetro(Circle(), interattivo: true, ripiego: .ultraThinMaterial, bordo: false)
                .environment(\.colorScheme, .dark)
                .contentShape(Circle())
        }
        .buttonStyle(Premuto(quanto: 0.88))
        .accessibilityLabel(etichetta)
    }
}

extension View {
    func carta(_ dentro: CGFloat = 14) -> some View {
        padding(dentro)
            .background(Tinta.superficie, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tinta.linea, lineWidth: 0.5))
    }

    func etichettaMaiuscola() -> some View {
        font(.system(size: 12.5, weight: .medium)).tracking(0.5).foregroundStyle(Tinta.tenue)
    }

    func foglioStile() -> some View {
        presentationBackground(Tinta.superficie)
            .presentationCornerRadius(26)
            .presentationDragIndicator(.visible)
    }

    func senzaBarraDiSistema() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }
}

extension NavigationPath {
    mutating func spingi<V: Hashable>(_ valore: V) { append(valore) }
}

extension EnvironmentValues {
    @Entry var vaiA: ((any Hashable) -> Void)? = nil
}

struct Collegamento<Valore: Hashable, Etichetta: View>: View {
    let valore: Valore
    let etichetta: Etichetta
    @Environment(\.vaiA) private var vai

    init(_ valore: Valore, @ViewBuilder etichetta: () -> Etichetta) {
        self.valore = valore
        self.etichetta = etichetta()
    }

    var body: some View {
        if let vai {
            Button { vai(valore) } label: { etichetta }
        } else {
            NavigationLink(value: valore) { etichetta }
        }
    }
}

struct Testa<Azioni: View>: View {
    let titolo: String
    var sottotitolo: String? = nil
    var indietro: (() -> Void)? = nil
    @ViewBuilder var azioni: () -> Azioni

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let indietro {
                Button(action: indietro) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                        Text("Indietro").font(.system(size: 15))
                    }
                    .foregroundStyle(Tinta.accento)
                    .frame(height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(Premuto())
            }
            HStack(alignment: .center, spacing: 8) {
                Text(titolo)
                    .font(indietro == nil ? Carattere.titolo : Carattere.titoletto.leading(.tight))
                    .foregroundStyle(Tinta.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                azioni()
                    .fixedSize()
                    .layoutPriority(1)
            }
            if let sottotitolo {
                Text(sottotitolo).font(Carattere.minore).foregroundStyle(Tinta.tenue).lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

struct TestaCompatta<Azioni: View>: View {
    let titolo: String
    var indietro: (() -> Void)? = nil
    @ViewBuilder var azioni: () -> Azioni

    var body: some View {
        HStack(spacing: 8) {
            if let indietro {
                Button(action: indietro) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tinta.accento)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(Premuto())
                .accessibilityLabel("Indietro")
            }
            Text(titolo).font(Carattere.piccolo).foregroundStyle(Tinta.ink).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: indietro == nil ? .leading : .center)
            azioni()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background { FondoTesta() }
    }
}

struct FondoTesta: View {
    @AppStorage(Vetro.chiave) private var vetro = true

    var body: some View {
        if Vetro.vero(vetro) {
            Rectangle().fill(.ultraThinMaterial)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.55),
                                             .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .padding(.bottom, -18)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        } else {
            Rectangle().fill(.bar)
                .overlay(alignment: .bottom) { Rectangle().fill(Tinta.linea).frame(height: 0.5) }
                .ignoresSafeArea(edges: .top)
        }
    }
}

struct SfumaturaTesta: View {
    var sotto: CGFloat = 28

    var body: some View {
        LinearGradient(stops: [.init(color: Tinta.fondo.opacity(0.94), location: 0),
                               .init(color: Tinta.fondo.opacity(0.72), location: 0.45),
                               .init(color: Tinta.fondo.opacity(0), location: 1)],
                       startPoint: .top, endPoint: .bottom)
            .padding(.bottom, -sotto)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

struct ConTestaCompatta<Azioni: View>: ViewModifier {
    let titolo: String
    let visibile: Bool
    var indietro: (() -> Void)?
    @ViewBuilder var azioni: () -> Azioni

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if visibile {
                TestaCompatta(titolo: titolo, indietro: indietro, azioni: azioni)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Moto.passo, value: visibile)
    }
}

extension View {
    func testaCompatta<A: View>(_ titolo: String, visibile: Bool, indietro: (() -> Void)? = nil,
                                @ViewBuilder azioni: @escaping () -> A) -> some View {
        modifier(ConTestaCompatta(titolo: titolo, visibile: visibile, indietro: indietro, azioni: azioni))
    }

    func segueLaTesta(_ compatta: Binding<Bool>) -> some View {
        onScrollGeometryChange(for: Bool.self) { g in
            g.contentOffset.y + g.contentInsets.top > 56
        } action: { _, nuovo in
            if compatta.wrappedValue != nuovo { compatta.wrappedValue = nuovo }
        }
    }
}

@MainActor
final class Annunci: ObservableObject {
    struct Uno: Equatable {
        let id = UUID()
        let testo: String
        let simbolo: String
    }

    @Published private(set) var adesso: Uno?
    private var timer: Task<Void, Never>?

    func di(_ testo: String, simbolo: String = "checkmark") {
        timer?.cancel()
        withAnimation(Moto.molla) { adesso = Uno(testo: testo, simbolo: simbolo) }
        timer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.9))
            guard !Task.isCancelled else { return }
            withAnimation(Moto.passo) { self.adesso = nil }
        }
    }
}

struct AvvisoPillola: View {
    let uno: Annunci.Uno

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: uno.simbolo)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Tinta.accento)
                .frame(width: 26, height: 26)
                .background(Tinta.alone, in: Circle())
            Text(uno.testo).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Tinta.ink).lineLimit(2)
        }
        .padding(.leading, 7)
        .padding(.trailing, 16)
        .padding(.vertical, 7)
        .vetro(Capsule(), ombra: true)
        .padding(.horizontal, 24)
    }
}

struct ConAnnunci: ViewModifier {
    @ObservedObject var annunci: Annunci
    var sopra: CGFloat = 84

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let uno = annunci.adesso {
                AvvisoPillola(uno: uno)
                    .id(uno.id)
                    .padding(.bottom, sopra)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity)
                                                .combined(with: .scale(scale: 0.94)),
                                            removal: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }
}

struct Vuoto: View {
    let titolo: String
    let testo: String
    var simbolo = "photo.on.rectangle"

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: simbolo).font(.system(size: 28, weight: .light)).foregroundStyle(Tinta.tenue)
            Text(titolo).font(Carattere.titoletto).foregroundStyle(Tinta.ink).multilineTextAlignment(.center)
            Text(testo).font(.system(size: 14)).foregroundStyle(Tinta.tenue).multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

struct Freccia: View {
    var body: some View {
        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tinta.tenue)
    }
}

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

struct Fila: Layout {
    var spazio: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        disponi(proposal.width ?? .infinity, subviews).1
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (posti, _) = disponi(bounds.width, subviews)
        for (i, p) in posti.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.minX, y: bounds.minY + p.minY),
                              proposal: ProposedViewSize(p.size))
        }
    }

    private func disponi(_ largo: CGFloat, _ subviews: Subviews) -> ([CGRect], CGSize) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var riga: CGFloat = 0
        var massimo: CGFloat = 0
        var posti: [CGRect] = []
        for v in subviews {
            var m = v.sizeThatFits(.unspecified)
            if m.width > largo {
                m = v.sizeThatFits(ProposedViewSize(width: largo, height: nil))
                m.width = min(m.width, largo)
            }
            if x > 0, x + m.width > largo {
                x = 0
                y += riga + spazio
                riga = 0
            }
            posti.append(CGRect(x: x, y: y, width: m.width, height: m.height))
            x += m.width + spazio
            riga = max(riga, m.height)
            massimo = max(massimo, x - spazio)
        }
        return (posti, CGSize(width: largo.isFinite ? largo : massimo, height: y + riga))
    }
}

struct FacciaVetrino: View {
    let simbolo: String

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Tinta.carta)
            .frame(width: 44, height: 44)
            .vetro(Circle(), interattivo: true, ripiego: .ultraThinMaterial, bordo: false)
            .environment(\.colorScheme, .dark)
            .contentShape(Circle())
    }
}

struct FacciaTondo: View {
    let simbolo: String

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Tinta.attenuato)
            .frame(width: 38, height: 38)
            .vetro(Circle(), interattivo: true)
            .contentShape(Circle())
    }
}

struct Riga<Icona: View>: View {
    let titolo: String
    var sottotitolo: String? = nil
    var numero: Int? = nil
    @ViewBuilder var icona: () -> Icona

    var body: some View {
        HStack(spacing: 12) {
            icona()
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Tinta.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let sottotitolo {
                    Text(sottotitolo).font(.system(size: 12.5)).foregroundStyle(Tinta.tenue).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            if let numero {
                Text(Testi.numero(numero))
                    .font(.system(size: 13)).foregroundStyle(Tinta.tenue).monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
            Freccia()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

struct Scheda<Dentro: View>: View {
    @ViewBuilder var dentro: () -> Dentro

    var body: some View {
        VStack(spacing: 0) { dentro() }
            .background(Tinta.superficie, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Tinta.linea, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct Separa: View {
    var rientro: CGFloat = 70

    var body: some View {
        Rectangle().fill(Tinta.linea).frame(height: 0.5).padding(.leading, rientro)
    }
}

struct Premibile: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Tinta.superficieAlta : Color.clear)
            .animation(Moto.gesto, value: configuration.isPressed)
    }
}

enum Vetro {
    static let chiave = "visore.vetro"

    static func vero(_ scelto: Bool) -> Bool {
        guard scelto, !UIAccessibility.isReduceTransparencyEnabled else { return false }
        if #available(iOS 26.0, *) { return true }
        return false
    }
}

struct ConVetro<Forma: Shape>: ViewModifier {
    let forma: Forma
    var tinta: Color?
    var interattivo: Bool
    var ripiego: AnyShapeStyle
    var bordo: Bool
    var ombra: Bool
    @AppStorage(Vetro.chiave) private var scelto = true
    @Environment(\.accessibilityReduceTransparency) private var poca

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), scelto, !poca {
            content.glassEffect(Glass.clear.tint(tinta).interactive(), in: forma)
        } else {
            content
                .background(ripiego, in: forma)
                .overlay { if bordo { forma.stroke(Tinta.lineaForte, lineWidth: 0.5) } }
                .shadow(color: ombra ? Tinta.ombra : .clear, radius: ombra ? 16 : 0, y: ombra ? 7 : 0)
        }
    }
}

struct GruppoDiVetro<Dentro: View>: View {
    var spazio: CGFloat = 8
    @ViewBuilder var dentro: () -> Dentro
    @AppStorage(Vetro.chiave) private var scelto = true

    var body: some View {
        if #available(iOS 26.0, *), scelto {
            GlassEffectContainer(spacing: spazio) { dentro() }
        } else {
            dentro()
        }
    }
}

extension View {
    func vetro<F: Shape, S: ShapeStyle>(_ forma: F, tinta: Color? = nil, interattivo: Bool = false,
                                        ripiego: S, bordo: Bool = true, ombra: Bool = false) -> some View {
        modifier(ConVetro(forma: forma, tinta: tinta, interattivo: interattivo, ripiego: AnyShapeStyle(ripiego),
                          bordo: bordo, ombra: ombra))
    }

    func vetro<F: Shape>(_ forma: F, tinta: Color? = nil, interattivo: Bool = false,
                         bordo: Bool = true, ombra: Bool = false) -> some View {
        vetro(forma, tinta: tinta, interattivo: interattivo, ripiego: Tinta.superficie, bordo: bordo, ombra: ombra)
    }
}
