import SwiftUI
import UIKit
import VisoreKit

struct Pianta {
    struct Gruppo {
        let inizio: Int
        let fine: Int
        let chiave: String?
        let alto: CGFloat
    }

    var celle: [CGRect] = []
    var gruppi: [Gruppo] = []
    var alto: CGFloat = 0
    var lato: CGFloat = 1
    var prefisso = 10

    var tipo: String { Pianta.tipo(prefisso) }

    static func tipo(_ prefisso: Int) -> String {
        prefisso == 10 ? "giorno" : (prefisso == 7 ? "mese" : "anno")
    }

    static func fai(_ scatti: [Scatto], largo: CGFloat, colonne: Int, prefisso: Int, cima: CGFloat,
                    testata: (String?, Int, Int) -> CGFloat) -> Pianta {
        var p = Pianta()
        p.prefisso = prefisso
        let sp: CGFloat = colonne >= 15 ? 1 : 2
        let lato = max(1, floor((largo - CGFloat(colonne - 1) * sp) / CGFloat(colonne)))
        p.lato = lato
        let passo = lato + sp
        let margine = max(0, floor((largo - CGFloat(colonne) * lato - CGFloat(colonne - 1) * sp) / 2))
        var celle = [CGRect](repeating: .zero, count: scatti.count)
        var y = cima
        var i = 0
        while i < scatti.count {
            let chiave = scatti[i].giorno.map { String($0.prefix(prefisso)) }
            var fine = i + 1
            while fine < scatti.count, scatti[fine].giorno.map({ String($0.prefix(prefisso)) }) == chiave {
                fine += 1
            }
            let h = testata(chiave, i, fine)
            p.gruppi.append(Gruppo(inizio: i, fine: fine, chiave: chiave, alto: h))
            y += h
            if colonne == 1 {
                for j in i..<fine {
                    let alta = floor(lato * Pianta.forma(scatti[j]))
                    celle[j] = CGRect(x: margine, y: y, width: lato, height: alta)
                    y += alta + sp
                }
                y -= sp
            } else {
                for j in i..<fine {
                    let k = j - i
                    celle[j] = CGRect(x: margine + CGFloat(k % colonne) * passo, y: y + CGFloat(k / colonne) * passo,
                                      width: lato, height: lato)
                }
                let righe = (fine - i + colonne - 1) / colonne
                y += CGFloat(righe) * passo - sp
            }
            i = fine
        }
        p.celle = celle
        p.alto = y
        return p
    }

    static func forma(_ s: Scatto) -> CGFloat {
        guard let w = s.larghezza, let h = s.altezza, w > 0, h > 0 else { return 1 }
        return min(1.8, max(0.3, CGFloat(h) / CGFloat(w)))
    }

    func gruppo(di i: Int) -> Int? {
        var basso = 0
        var alto = gruppi.count - 1
        guard alto >= 0 else { return nil }
        while basso < alto {
            let mezzo = (basso + alto + 1) / 2
            if gruppi[mezzo].inizio <= i { basso = mezzo } else { alto = mezzo - 1 }
        }
        return basso
    }
}

final class Disposizione: UICollectionViewLayout {
    var da = Pianta()
    var a = Pianta()
    var t: CGFloat = 0
    var largo: CGFloat = 0

    var quante: Int { da.celle.count }

    func cella(_ i: Int) -> CGRect {
        let p = da.celle[i]
        guard t != 0, a.celle.count == da.celle.count else { return p }
        let q = a.celle[i]
        return CGRect(x: p.minX + (q.minX - p.minX) * t, y: p.minY + (q.minY - p.minY) * t,
                      width: p.width + (q.width - p.width) * t, height: p.height + (q.height - p.height) * t)
    }

    var alto: CGFloat {
        guard a.celle.count == da.celle.count else { return da.alto }
        return da.alto + (a.alto - da.alto) * t
    }

    var lato: CGFloat {
        guard a.celle.count == da.celle.count else { return da.lato }
        return da.lato + (a.lato - da.lato) * t
    }

    override var collectionViewContentSize: CGSize { CGSize(width: largo, height: alto) }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { false }

    func primo(_ y: CGFloat) -> Int {
        var basso = 0
        var alto = quante
        while basso < alto {
            let mezzo = (basso + alto) / 2
            if cella(mezzo).maxY < y { basso = mezzo + 1 } else { alto = mezzo }
        }
        return basso
    }

    func sotto(_ p: CGPoint) -> Int? {
        guard quante > 0 else { return nil }
        var i = min(primo(p.y), quante - 1)
        let riga = cella(i).minY
        if p.y < riga, i > 0, riga - p.y > p.y - cella(i - 1).maxY { i -= 1 }
        let su = cella(i).minY
        var j = i
        while j > 0, cella(j - 1).minY == su { j -= 1 }
        while j + 1 < quante, cella(j + 1).minY == su, cella(j).maxX < p.x { j += 1 }
        return j
    }

    private func pesi() -> (CGFloat, CGFloat) {
        guard t > 0, a.celle.count == da.celle.count, a.tipo != da.tipo else { return (1, 0) }
        return (max(0, 1 - 2 * t), max(0, 2 * t - 1))
    }

    private func testata(_ p: Pianta, _ g: Int, _ peso: CGFloat) -> UICollectionViewLayoutAttributes {
        let gruppo = p.gruppi[g]
        let attr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: p.tipo,
                                                    with: IndexPath(item: g, section: 0))
        let su = gruppo.inizio < quante ? cella(gruppo.inizio).minY : 0
        attr.frame = CGRect(x: 0, y: su - gruppo.alto, width: largo, height: gruppo.alto)
        attr.alpha = peso
        attr.zIndex = 1
        return attr
    }

    private func testate(_ p: Pianta, _ peso: CGFloat, _ rect: CGRect, _ uscita: inout [UICollectionViewLayoutAttributes]) {
        guard peso > 0, !p.gruppi.isEmpty else { return }
        var basso = 0
        var alto = p.gruppi.count
        while basso < alto {
            let mezzo = (basso + alto) / 2
            if cella(p.gruppi[mezzo].inizio).minY < rect.minY { basso = mezzo + 1 } else { alto = mezzo }
        }
        var g = basso
        while g < p.gruppi.count {
            let attr = testata(p, g, peso)
            if attr.frame.minY > rect.maxY { break }
            if attr.frame.intersects(rect) { uscita.append(attr) }
            g += 1
        }
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var uscita: [UICollectionViewLayoutAttributes] = []
        var i = primo(rect.minY)
        while i < quante {
            let f = cella(i)
            if f.minY > rect.maxY { break }
            if f.intersects(rect) {
                let attr = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
                attr.frame = f
                uscita.append(attr)
            }
            i += 1
        }
        let (primoPeso, secondoPeso) = pesi()
        testate(da, primoPeso, rect, &uscita)
        if secondoPeso > 0 { testate(a, secondoPeso, rect, &uscita) }
        return uscita
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < quante else { return nil }
        let attr = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attr.frame = cella(indexPath.item)
        return attr
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: String,
                                                       at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let (primoPeso, secondoPeso) = pesi()
        if da.tipo == elementKind, indexPath.item < da.gruppi.count { return testata(da, indexPath.item, primoPeso) }
        if a.tipo == elementKind, indexPath.item < a.gruppi.count, a.celle.count == da.celle.count {
            return testata(a, indexPath.item, secondoPeso)
        }
        let attr = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: elementKind, with: indexPath)
        attr.alpha = 0
        attr.isHidden = true
        return attr
    }
}

final class CellaFoto: UICollectionViewCell {
    private let foto = UIImageView()
    private let velo = UIView()
    private let durata = UILabel()
    private let live = UIImageView()
    private let cuore = UIImageView()
    private let spunta = UIImageView()
    private var lavoro: Task<Void, Never>?
    private(set) var id: Int64?
    private var caricato: CGFloat = 0
    private var chiesto: CGFloat = 0
    private var video = false
    private var mossa = false
    private var colCuore = false
    private var scelto: Bool?

    static let arancio = UIColor(Tinta.arancio)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = UIColor(Tinta.pozzo)
        contentView.clipsToBounds = true
        contentView.layer.cornerCurve = .continuous
        foto.contentMode = .scaleAspectFill
        foto.clipsToBounds = true
        foto.accessibilityIgnoresInvertColors = true
        contentView.addSubview(foto)
        velo.backgroundColor = UIColor(Tinta.accento)
        velo.alpha = 0
        contentView.addSubview(velo)
        durata.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        durata.textColor = .white
        for v in [durata, live, cuore, spunta] as [UIView] {
            v.layer.shadowColor = UIColor.black.cgColor
            v.layer.shadowOpacity = 0.6
            v.layer.shadowRadius = 2
            v.layer.shadowOffset = .zero
            v.isHidden = true
            contentView.addSubview(v)
        }
        let piccolo = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        live.image = UIImage(systemName: "livephoto", withConfiguration: piccolo)
        live.tintColor = .white
        cuore.image = UIImage(systemName: "heart.fill", withConfiguration: piccolo)
        cuore.tintColor = .white
        spunta.layer.shadowOpacity = 0.4
        isAccessibilityElement = true
        accessibilityTraits = .image
    }

    required init?(coder: NSCoder) { nil }

    override func prepareForReuse() {
        super.prepareForReuse()
        lavoro?.cancel()
        lavoro = nil
        chiesto = 0
        contentView.transform = .identity
    }

    func mostra(_ s: Scatto, pacchetto: Pacchetto, px: CGFloat, proporzioni: Bool, cuore acceso: Bool,
                scelto quale: Bool?, animato: Bool) {
        if id != s.id {
            id = s.id
            caricato = 0
            chiesto = 0
            lavoro?.cancel()
            lavoro = nil
            foto.image = nil
            foto.alpha = 1
        }
        foto.contentMode = proporzioni ? .scaleAspectFit : .scaleAspectFill
        video = s.video
        mossa = s.live
        durata.text = s.video ? Testi.durata(s.durataMs) : nil
        let primaScelto = scelto
        colCuore = acceso
        scelto = quale
        accessibilityLabel = s.video ? "Video" : "Foto"
        accessibilityValue = quale == true ? "Scelta" : nil
        let piccolo = quale == true ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
        if animato, primaScelto != quale {
            UIView.animate(springDuration: 0.34, bounce: 0.28, initialSpringVelocity: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.contentView.transform = piccolo
            }
        } else {
            contentView.transform = piccolo
        }
        segni()
        setNeedsLayout()
        carica(s, pacchetto: pacchetto, px: px)
    }

    private func carica(_ s: Scatto, pacchetto: Pacchetto, px: CGFloat) {
        let piccola = s.mini ?? s.posto
        let fonte = px > 700 && !s.video ? s.posto : piccola
        let serve = Miniature.scalino(px)
        guard caricato < serve else { return }
        if lavoro != nil, chiesto >= serve { return }
        if let pronta = Miniature.tutte.pronta(fonte, lato: px) {
            foto.image = pronta
            caricato = serve
            lavoro?.cancel()
            lavoro = nil
            return
        }
        if foto.image == nil { foto.image = Miniature.tutte.pronta(fonte) ?? Miniature.tutte.pronta(piccola) }
        let avevo = foto.image != nil
        let id = s.id
        lavoro?.cancel()
        chiesto = serve
        lavoro = Task { [weak self] in
            var nuova = await Miniature.tutte.carica(pacchetto, fonte, lato: px)
            if nuova == nil, fonte != piccola { nuova = await Miniature.tutte.carica(pacchetto, piccola, lato: px) }
            guard let self, let nuova, !Task.isCancelled, self.id == id else { return }
            self.caricato = serve
            self.lavoro = nil
            if avevo {
                UIView.transition(with: self.foto, duration: 0.18,
                                  options: [.transitionCrossDissolve, .allowUserInteraction]) {
                    self.foto.image = nuova
                }
            } else {
                self.foto.alpha = 0
                self.foto.image = nuova
                UIView.animate(withDuration: 0.22, delay: 0, options: [.allowUserInteraction]) { self.foto.alpha = 1 }
            }
        }
    }

    private func segni() {
        let w = bounds.width
        durata.isHidden = !(video && w > 50)
        live.isHidden = !(mossa && !video && w > 60)
        cuore.isHidden = !(colCuore && w > 40)
        contentView.layer.cornerRadius = w > 60 ? 3 : 1
        if let scelto {
            if w <= 30 {
                spunta.isHidden = true
                velo.alpha = scelto ? 0.45 : 0
            } else {
                velo.alpha = scelto ? 0.18 : 0
                spunta.isHidden = false
                let forma = UIImage.SymbolConfiguration(pointSize: 21)
                if scelto {
                    let colori = UIImage.SymbolConfiguration(paletteColors: [.white, CellaFoto.arancio])
                    spunta.image = UIImage(systemName: "checkmark.circle.fill",
                                           withConfiguration: forma.applying(colori))
                } else {
                    spunta.image = UIImage(systemName: "circle", withConfiguration: forma)
                    spunta.tintColor = .white
                }
            }
        } else {
            spunta.isHidden = true
            velo.alpha = 0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds
        foto.frame = b
        velo.frame = b
        segni()
        if !durata.isHidden {
            durata.sizeToFit()
            durata.frame.origin = CGPoint(x: b.maxX - durata.frame.width - 5, y: b.maxY - durata.frame.height - 5)
        }
        if !live.isHidden {
            live.sizeToFit()
            live.frame.origin = CGPoint(x: b.maxX - live.frame.width - 5, y: b.maxY - live.frame.height - 5)
        }
        if !cuore.isHidden {
            cuore.sizeToFit()
            cuore.frame.origin = CGPoint(x: 5, y: b.maxY - cuore.frame.height - 5)
        }
        if !spunta.isHidden {
            spunta.sizeToFit()
            spunta.frame.origin = CGPoint(x: b.maxX - spunta.frame.width - 5, y: b.maxY - spunta.frame.height - 5)
        }
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes
    }
}

final class CellaTestata: UICollectionViewCell {
    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes
    }
}

@MainActor
final class Molla: NSObject {
    private var link: CADisplayLink?
    private var valore: CGFloat = 0
    private var velocita: CGFloat = 0
    private var meta: CGFloat = 0
    private var ultimo: CFTimeInterval = 0
    private var passo: ((CGFloat) -> Void)?
    private var fine: (() -> Void)?

    var attiva: Bool { link != nil }

    func vai(da: CGFloat, a: CGFloat, velocita v: CGFloat, passo: @escaping (CGFloat) -> Void,
             fine: @escaping () -> Void) {
        ferma()
        valore = da
        velocita = v
        meta = a
        self.passo = passo
        self.fine = fine
        ultimo = CACurrentMediaTime()
        let l = CADisplayLink(target: self, selector: #selector(batti(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func ferma() {
        link?.invalidate()
        link = nil
    }

    @objc private func batti(_ l: CADisplayLink) {
        let ora = CACurrentMediaTime()
        let dt = min(1.0 / 30, max(0, ora - ultimo))
        ultimo = ora
        let k = pow(2 * CGFloat.pi / 0.36, 2)
        let c = 2 * sqrt(k) * 0.95
        let h = CGFloat(dt) / 6
        for _ in 0..<6 {
            let forza = -k * (valore - meta) - c * velocita
            velocita += forza * h
            valore += velocita * h
        }
        if abs(valore - meta) < 0.002, abs(velocita) < 0.08 {
            let finale = fine
            passo?(meta)
            ferma()
            finale?()
            return
        }
        passo?(min(1.03, max(-0.03, valore)))
    }
}

@MainActor
final class Timone {
    weak var griglia: GrigliaController?

    func vai(_ giorno: String) { griglia?.vai(giorno) }
    func inCima() { griglia?.inCima() }
}

struct AzioniGriglia {
    var livello: (Int) -> Void
    var compatta: (Bool) -> Void
    var etichetta: (String?, Bool) -> Void
    var altri: () -> Void
    var cambia: (Int64) -> Void
    var tenuto: (Scatto?) -> Void
    var apri: (Int) -> AnyView?
    var aperto: (Bool) -> Void
    var intestazione: (GruppoDelGiorno) -> AnyView
}

struct GrigliaNativa: UIViewControllerRepresentable {
    let pacchetto: Pacchetto
    let scatti: [Scatto]
    let finiti: Bool
    let perGiorno: [String: Giorno]
    let livello: Int
    let proporzioni: Bool
    let cuori: Set<String>
    let scelti: Set<Int64>?
    let visto: Int64
    let cima: AnyView
    let fondo: CGFloat
    let timone: Timone
    let azioni: AzioniGriglia

    func makeUIViewController(context: Context) -> GrigliaController {
        let c = GrigliaController(dati: self)
        timone.griglia = c
        return c
    }

    func updateUIViewController(_ c: GrigliaController, context: Context) {
        timone.griglia = c
        c.aggiorna(self)
    }
}

private struct Cima: View {
    let dentro: AnyView
    let misura: (CGFloat) -> Void

    var body: some View {
        dentro
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { misura($0) }
    }
}

final class Ospite: UIHostingController<AnyView> {
    var chiuso: (() -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed { chiuso?() }
    }
}

final class GrigliaController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate,
    UIGestureRecognizerDelegate {
    private var dati: GrigliaNativa
    private let disposizione = Disposizione()
    private var vista: UICollectionView!
    private let cima = UIHostingController(rootView: AnyView(EmptyView()))
    private var scatti: [Scatto] = []
    private var livello: Int
    private var livelloDaFuori: Int
    private var piante: [Int: Pianta] = [:]
    private var altezzaCima: CGFloat = 0
    private var largo: CGFloat = 0
    private var sopra: CGFloat = 0
    private var altezze: [String: CGFloat] = [:]
    private var chiestoA = -1
    private var meta: String?
    private var visto: Int64
    private var compatta = false
    private var etichetta: String?
    private var ultimoY: CGFloat = 0
    private let molla = Molla()
    private let tocco = UISelectionFeedbackGenerator()
    private var verso: Int?
    private var base: CGFloat = 1
    private var ancora = 0
    private var relativo: CGFloat = 0
    private var ditoY: CGFloat = 0
    private var pizzicando = false
    private var inSospeso = false

    static let livelli = [1, 3, 5, 15, 31]
    static let livelliLarghi = [3, 7, 9, 25, 51]
    static let prefissi = [10, 10, 10, 7, 4]

    init(dati: GrigliaNativa) {
        self.dati = dati
        livello = dati.livello
        livelloDaFuori = dati.livello
        visto = dati.visto
        scatti = dati.scatti
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        vista = UICollectionView(frame: view.bounds, collectionViewLayout: disposizione)
        vista.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vista.backgroundColor = .clear
        vista.contentInsetAdjustmentBehavior = .always
        vista.showsVerticalScrollIndicator = false
        vista.alwaysBounceVertical = true
        vista.dataSource = self
        vista.delegate = self
        vista.register(CellaFoto.self, forCellWithReuseIdentifier: "foto")
        for tipo in ["giorno", "mese", "anno"] {
            vista.register(CellaTestata.self, forSupplementaryViewOfKind: tipo, withReuseIdentifier: tipo)
        }
        view.addSubview(vista)
        cima.view.backgroundColor = .clear
        cima.safeAreaRegions = []
        addChild(cima)
        vista.addSubview(cima.view)
        cima.didMove(toParent: self)
        let pizzico = UIPinchGestureRecognizer(target: self, action: #selector(pizzica(_:)))
        pizzico.delegate = self
        vista.addGestureRecognizer(pizzico)
        let tieni = UILongPressGestureRecognizer(target: self, action: #selector(tieni(_:)))
        tieni.minimumPressDuration = 0.35
        tieni.delegate = self
        vista.addGestureRecognizer(tieni)
        vista.contentInset.bottom = dati.fondo
        mettiCima()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.largo = 0
            self.view.setNeedsLayout()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let su = vista.adjustedContentInset.top
        if su != sopra {
            if abs(vista.contentOffset.y + sopra) < 0.5 { vista.contentOffset.y = -su }
            sopra = su
        }
        let w = vista.bounds.width
        guard w > 0, w != largo else { return }
        let fermo = primoVisibile()
        largo = w
        disposizione.largo = w
        misuraTestate()
        let h = UIHostingController(rootView: dati.cima).sizeThatFits(
            in: CGSize(width: w, height: .greatestFiniteMagnitude)).height
        if h > 0, h.isFinite { altezzaCima = ceil(h) }
        cima.view.frame = CGRect(x: 0, y: 0, width: w, height: altezzaCima)
        rifai()
        if let fermo { riporta(fermo) } else { vista.contentOffset.y = -vista.adjustedContentInset.top }
    }

    private var largoSchermo: Bool { view.bounds.width > view.bounds.height * 1.2 }

    private func colonne(_ i: Int) -> Int {
        largoSchermo ? GrigliaController.livelliLarghi[i] : GrigliaController.livelli[i]
    }

    private func pianta(_ i: Int) -> Pianta {
        if let p = piante[i] { return p }
        let prefisso = GrigliaController.prefissi[i]
        let tipo = Pianta.tipo(prefisso)
        let per = dati.perGiorno
        let p = Pianta.fai(scatti, largo: largo, colonne: colonne(i), prefisso: prefisso, cima: altezzaCima) {
            [altezze, scatti] chiave, inizio, fine in
            guard tipo == "giorno" else { return altezze[tipo] ?? 44 }
            let conLuoghi: Bool
            if let chiave, let g = per[chiave] {
                conLuoghi = !g.luoghi.isEmpty
            } else {
                conLuoghi = scatti[inizio..<fine].contains { $0.luogo != nil }
            }
            return altezze[conLuoghi ? "giornoLuoghi" : "giorno"] ?? 50
        }
        piante[i] = p
        return p
    }

    private func misuraTestate() {
        func alto<V: View>(_ v: V) -> CGFloat {
            ceil(UIHostingController(rootView: v).sizeThatFits(
                in: CGSize(width: largo, height: .greatestFiniteMagnitude)).height)
        }
        altezze["giorno"] = alto(Intestazione(giorno: "2026-11-22", luoghi: [], quante: 3))
        altezze["giornoLuoghi"] = alto(Intestazione(giorno: "2026-11-22", luoghi: ["Roma"], quante: 3))
        altezze["mese"] = alto(IntestazioneBreve(testo: "Nov 2026", grande: false))
        altezze["anno"] = alto(IntestazioneBreve(testo: "2026", grande: true))
    }

    private func rifai() {
        piante.removeAll()
        let p = pianta(livello)
        disposizione.da = p
        disposizione.a = p
        disposizione.t = 0
        disposizione.invalidateLayout()
    }

    private func primoVisibile() -> (Int, CGFloat)? {
        guard largo > 0, disposizione.quante > 0 else { return nil }
        let y = vista.contentOffset.y + vista.adjustedContentInset.top
        guard y > altezzaCima else { return nil }
        let i = min(disposizione.primo(y), disposizione.quante - 1)
        return (i, disposizione.cella(i).minY - vista.contentOffset.y)
    }

    private func riporta(_ fermo: (Int, CGFloat)) {
        guard fermo.0 < disposizione.quante else { return }
        vista.contentOffset.y = limita(disposizione.cella(fermo.0).minY - fermo.1)
        vista.layoutIfNeeded()
    }

    private func limita(_ y: CGFloat) -> CGFloat {
        let su = -vista.adjustedContentInset.top
        let giu = max(su, disposizione.alto + vista.adjustedContentInset.bottom - vista.bounds.height)
        return min(max(y, su), giu)
    }

    private func mettiCima() {
        cima.rootView = AnyView(Cima(dentro: dati.cima) { [weak self] h in
            DispatchQueue.main.async { self?.cimaAlta(h) }
        })
    }

    private func cimaAlta(_ h: CGFloat) {
        let nuova = ceil(h)
        guard nuova > 0, abs(nuova - altezzaCima) > 0.5, largo > 0 else { return }
        if pizzicando || molla.attiva {
            inSospeso = true
            return
        }
        let differenza = nuova - altezzaCima
        let sotto = vista.contentOffset.y + vista.adjustedContentInset.top > altezzaCima
        altezzaCima = nuova
        cima.view.frame = CGRect(x: 0, y: 0, width: largo, height: nuova)
        rifai()
        if sotto { vista.contentOffset.y += differenza }
        vista.layoutIfNeeded()
    }

    func aggiorna(_ nuovi: GrigliaNativa) {
        let vecchi = dati
        dati = nuovi
        mettiCima()
        if vista == nil { return }
        if vista.contentInset.bottom != nuovi.fondo { vista.contentInset.bottom = nuovi.fondo }
        if nuovi.livello != livelloDaFuori {
            livelloDaFuori = nuovi.livello
            if nuovi.livello != livello, !pizzicando, !molla.attiva { salta(nuovi.livello) }
        }
        let cambiati = nuovi.scatti.count != scatti.count || nuovi.scatti.first?.id != scatti.first?.id
            || nuovi.scatti.last?.id != scatti.last?.id
        if cambiati {
            if pizzicando || molla.attiva { inSospeso = true } else { metti() }
        } else if nuovi.cuori != vecchi.cuori || nuovi.scelti != vecchi.scelti
                    || nuovi.proporzioni != vecchi.proporzioni {
            rivedi(animato: true)
        }
        if nuovi.scelti != vecchi.scelti || nuovi.scelti != nil { rivediTestate() }
        if nuovi.visto != visto {
            visto = nuovi.visto
            if presentedViewController != nil { mostra(visto) }
        }
    }

    private func metti() {
        let vecchi = scatti
        scatti = dati.scatti
        guard largo > 0 else {
            vista.reloadData()
            return
        }
        let aggiunti = scatti.count > vecchi.count && !vecchi.isEmpty
            && scatti[vecchi.count - 1].id == vecchi[vecchi.count - 1].id && scatti[0].id == vecchi[0].id
        let fermo = primoVisibile()
        rifai()
        if aggiunti {
            let nuovi = (vecchi.count..<scatti.count).map { IndexPath(item: $0, section: 0) }
            UIView.performWithoutAnimation {
                vista.performBatchUpdates { vista.insertItems(at: nuovi) }
            }
        } else {
            vista.reloadData()
            if let fermo { riporta(fermo) }
        }
        chiestoA = -1
        if let meta { prova(meta) }
    }

    private func salta(_ nuovo: Int) {
        let fermo = primoVisibile()
        livello = nuovo
        rifai()
        if let fermo { riporta(fermo) }
        rivedi(animato: false)
        aggiornaEtichetta(forza: true)
    }

    private func px(_ i: Int) -> CGFloat {
        var lato: CGFloat = 0
        for p in [disposizione.da, disposizione.a] where i < p.celle.count {
            lato = max(lato, p.celle[i].width, p.celle[i].height)
        }
        return max(1, lato) * max(1, traitCollection.displayScale)
    }

    private func rivedi(animato: Bool) {
        for ip in vista.indexPathsForVisibleItems {
            guard ip.item < scatti.count, let c = vista.cellForItem(at: ip) as? CellaFoto else { continue }
            configura(c, ip.item, px: px(ip.item), animato: animato)
        }
    }

    private func rivediTestate() {
        for tipo in ["giorno", "mese", "anno"] {
            for ip in vista.indexPathsForVisibleSupplementaryElements(ofKind: tipo) {
                if let v = vista.supplementaryView(forElementKind: tipo, at: ip) as? CellaTestata {
                    configuraTestata(v, tipo, ip.item)
                }
            }
        }
    }

    private func configura(_ c: CellaFoto, _ i: Int, px: CGFloat, animato: Bool) {
        let s = scatti[i]
        c.mostra(s, pacchetto: dati.pacchetto, px: px, proporzioni: dati.proporzioni,
                 cuore: dati.cuori.contains(s.impronta), scelto: dati.scelti.map { $0.contains(s.id) },
                 animato: animato)
    }

    private func configuraTestata(_ v: CellaTestata, _ tipo: String, _ g: Int) {
        let p = disposizione.da.tipo == tipo ? disposizione.da : disposizione.a
        guard g < p.gruppi.count else { return }
        let gruppo = p.gruppi[g]
        let fine = min(gruppo.fine, scatti.count)
        let dentro = gruppo.inizio < fine ? Array(scatti[gruppo.inizio..<fine]) : []
        let contenuto = dati.azioni.intestazione(GruppoDelGiorno(giorno: gruppo.chiave, scatti: dentro,
                                                                 per: p.prefisso))
        v.contentConfiguration = UIHostingConfiguration {
            contenuto.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .margins(.all, 0)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        scatti.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: "foto", for: indexPath)
        if let foto = c as? CellaFoto, indexPath.item < scatti.count {
            configura(foto, indexPath.item, px: px(indexPath.item), animato: false)
        }
        return c
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let v = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: kind, for: indexPath)
        if let t = v as? CellaTestata { configuraTestata(t, kind, indexPath.item) }
        return v
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard !dati.finiti, indexPath.item >= scatti.count - 150, chiestoA != scatti.count else { return }
        chiestoA = scatti.count
        let altri = dati.azioni.altri
        DispatchQueue.main.async { altri() }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard indexPath.item < scatti.count else { return }
        if dati.scelti == nil { apri(indexPath.item) } else { dati.azioni.cambia(scatti[indexPath.item].id) }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let y = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        if !pizzicando, !molla.attiva { aggiornaCompatta() }
        if !pizzicando, !molla.attiva { aggiornaEtichetta(forza: false) }
    }

    private func aggiornaCompatta() {
        let y = vista.contentOffset.y + vista.adjustedContentInset.top
        let nuova = y > 56
        if nuova != compatta {
            compatta = nuova
            let azione = dati.azioni.compatta
            DispatchQueue.main.async { azione(nuova) }
        }
    }

    private func aggiornaEtichetta(forza: Bool) {
        let p = disposizione.da
        guard p.prefisso < 10, !p.gruppi.isEmpty, disposizione.t == 0 else {
            if etichetta != nil {
                etichetta = nil
                let azione = dati.azioni.etichetta
                DispatchQueue.main.async { azione(nil, true) }
            }
            return
        }
        let y = vista.contentOffset.y + vista.adjustedContentInset.top + 74
        var basso = 0
        var alto = p.gruppi.count - 1
        while basso < alto {
            let mezzo = (basso + alto + 1) / 2
            if p.celle[p.gruppi[mezzo].inizio].minY - 40 <= y { basso = mezzo } else { alto = mezzo - 1 }
        }
        let chiave = p.gruppi[basso].chiave
        let giu = vista.contentOffset.y >= ultimoY
        ultimoY = vista.contentOffset.y
        guard forza || chiave != etichetta else { return }
        etichetta = chiave
        let azione = dati.azioni.etichetta
        DispatchQueue.main.async { azione(chiave, giu) }
    }

    func vai(_ giorno: String) {
        meta = giorno
        prova(giorno)
    }

    private func prova(_ giorno: String) {
        guard largo > 0 else { return }
        let p = disposizione.da
        let chiave = String(giorno.prefix(p.prefisso))
        guard let g = p.gruppi.firstIndex(where: { $0.chiave == chiave }) else { return }
        meta = nil
        let gruppo = p.gruppi[g]
        molla.ferma()
        vista.setContentOffset(CGPoint(x: vista.contentOffset.x,
                                       y: limita(p.celle[gruppo.inizio].minY - gruppo.alto
                                                 - vista.adjustedContentInset.top)), animated: false)
    }

    func inCima() {
        vista.setContentOffset(CGPoint(x: vista.contentOffset.x, y: -vista.adjustedContentInset.top), animated: true)
    }

    private func apri(_ i: Int) {
        guard presentedViewController == nil, let contenuto = dati.azioni.apri(i) else { return }
        visto = scatti[i].id
        let bordi = view.window?.safeAreaInsets ?? Gesti.bordi
        let ospite = Ospite(rootView: AnyView(contenuto.safeAreaPadding(
            EdgeInsets(top: bordi.top, leading: bordi.left, bottom: bordi.bottom, trailing: bordi.right))))
        ospite.safeAreaRegions = []
        ospite.modalPresentationStyle = .fullScreen
        ospite.chiuso = { [weak self] in self?.dati.azioni.aperto(false) }
        let opzioni = UIViewController.Transition.ZoomOptions()
        opzioni.interactiveDismissShouldBegin = { _ in false }
        ospite.preferredTransition = .zoom(options: opzioni) { [weak self] _ in self?.sorgente() }
        dati.azioni.aperto(true)
        present(ospite, animated: true)
    }

    private func sorgente() -> UIView? {
        guard let i = scatti.firstIndex(where: { $0.id == visto }) else { return nil }
        let ip = IndexPath(item: i, section: 0)
        if vista.cellForItem(at: ip) == nil { mostra(visto) }
        return vista.cellForItem(at: ip)
    }

    private func mostra(_ id: Int64) {
        guard let i = scatti.firstIndex(where: { $0.id == id }) else { return }
        let f = disposizione.cella(i)
        let alto = vista.bounds.height
        let su = vista.contentOffset.y + vista.adjustedContentInset.top
        let giu = vista.contentOffset.y + alto - vista.adjustedContentInset.bottom
        if f.minY >= su, f.maxY <= giu { return }
        vista.contentOffset.y = limita(f.midY - alto / 2)
        vista.layoutIfNeeded()
    }

    @objc private func tieni(_ g: UILongPressGestureRecognizer) {
        switch g.state {
        case .began:
            let p = g.location(in: vista)
            guard let ip = vista.indexPathForItem(at: p), ip.item < scatti.count else { return }
            dati.azioni.tenuto(scatti[ip.item])
        case .ended, .cancelled, .failed:
            dati.azioni.tenuto(nil)
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        if g is UILongPressGestureRecognizer {
            guard !pizzicando, !molla.attiva, disposizione.lato > 40 else { return false }
            return vista.indexPathForItem(at: g.location(in: vista)) != nil
        }
        if g is UIPinchGestureRecognizer {
            return presentedViewController == nil && disposizione.quante > 0 && largo > 0
        }
        return true
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith altro: UIGestureRecognizer) -> Bool {
        g is UIPinchGestureRecognizer && altro === vista.panGestureRecognizer
    }

    private func lato(_ i: Int) -> CGFloat { pianta(i).lato }

    @objc private func pizzica(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            inizia(g)
        case .changed:
            segui(g)
        case .ended, .cancelled, .failed:
            lascia(g)
        default:
            break
        }
    }

    private func inizia(_ g: UIPinchGestureRecognizer) {
        let stavaAndando = molla.attiva
        molla.ferma()
        pizzicando = true
        tocco.prepare()
        vista.setContentOffset(vista.contentOffset, animated: false)
        vista.panGestureRecognizer.isEnabled = false
        if !stavaAndando {
            disposizione.a = disposizione.da
            disposizione.t = 0
            verso = nil
        }
        let latoOra = disposizione.lato
        base = g.scale * lato(livello) / max(1, latoOra)
        let p = g.location(in: vista)
        ditoY = g.location(in: view).y - vista.frame.minY
        if let k = disposizione.sotto(p) {
            ancora = k
            let f = disposizione.cella(k)
            relativo = (p.y - f.minY) / max(1, f.height)
        }
    }

    private func bersaglio(_ q: CGFloat) -> Int? {
        let b = q >= 1 ? livello - 1 : livello + 1
        return GrigliaController.livelli.indices.contains(b) ? b : nil
    }

    private func progresso(_ q: CGFloat, _ b: Int) -> CGFloat {
        let a = lato(livello)
        let d = lato(b) - a
        guard abs(d) > 0.01 else { return 0 }
        return min(1, max(0, (a * q - a) / d))
    }

    private func segui(_ g: UIPinchGestureRecognizer) {
        ditoY = g.location(in: view).y - vista.frame.minY
        var q = g.scale / base
        var b = bersaglio(q)
        var t = b.map { progresso(q, $0) } ?? 0
        while t >= 1, let fatto = b, let oltre = bersaglio(q), oltre == fatto,
              GrigliaController.livelli.indices.contains(fatto + (fatto - livello)) {
            livello = fatto
            tocco.selectionChanged()
            tocco.prepare()
            base = g.scale
            q = 1
            b = nil
            t = 0
        }
        let nuovo = b != verso
        verso = b
        applica(b ?? livello, t)
        if nuovo, b != nil { rivedi(animato: false) }
    }

    private func applica(_ b: Int, _ t: CGFloat) {
        disposizione.da = pianta(livello)
        disposizione.a = pianta(b)
        disposizione.t = t
        disposizione.invalidateLayout()
        guard ancora < disposizione.quante else { return }
        let f = disposizione.cella(ancora)
        vista.contentOffset = CGPoint(x: vista.contentOffset.x, y: limita(f.minY + relativo * f.height - ditoY))
        vista.layoutIfNeeded()
    }

    private func lascia(_ g: UIPinchGestureRecognizer) {
        pizzicando = false
        guard let b = verso else {
            chiudi(livello)
            return
        }
        let t = disposizione.t
        let a = lato(livello)
        let d = lato(b) - a
        var v = abs(d) > 0.01 ? g.velocity / max(0.01, base) * a / d : 0
        v = min(10, max(-10, v))
        let meta: CGFloat = g.state == .ended && t + v * 0.12 > 0.5 ? 1 : 0
        if meta == 1 { tocco.selectionChanged() }
        molla.vai(da: t, a: meta, velocita: v, passo: { [weak self] x in
            self?.applica(b, x)
        }, fine: { [weak self] in
            self?.chiudi(meta == 1 ? b : nil)
        })
    }

    private func chiudi(_ nuovo: Int?) {
        if let nuovo { livello = nuovo }
        verso = nil
        applica(livello, 0)
        vista.panGestureRecognizer.isEnabled = true
        if livello != livelloDaFuori {
            let fatto = livello
            let azione = dati.azioni.livello
            DispatchQueue.main.async { azione(fatto) }
        }
        rivedi(animato: false)
        aggiornaCompatta()
        aggiornaEtichetta(forza: true)
        if inSospeso {
            inSospeso = false
            if dati.scatti.count != scatti.count || dati.scatti.last?.id != scatti.last?.id { metti() }
        }
    }
}
