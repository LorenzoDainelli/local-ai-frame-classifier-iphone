import AVFoundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisoreKit

final class VideoCifrato: NSObject, AVAssetResourceLoaderDelegate {

    static let schema = "visore-cifrato"
    private static let pezzo = 256 * 1024

    let lettore: LettoreCifrato
    let asset: AVURLAsset
    private let coda = DispatchQueue(label: "visore.video")
    private let tipo: String

    init(pacchetto: Pacchetto, posto: String) throws {
        lettore = try pacchetto.lettore(posto)
        let testa = (try? lettore.leggi(da: 0, quanti: 12)) ?? Data()
        let marca = testa.count >= 12 ? String(decoding: testa[testa.startIndex + 8..<testa.startIndex + 12], as: UTF8.self) : ""
        tipo = marca == "qt  " ? UTType.quickTimeMovie.identifier : UTType.mpeg4Movie.identifier
        asset = AVURLAsset(url: URL(string: "\(VideoCifrato.schema)://\(UUID().uuidString)")!)
        super.init()
        asset.resourceLoader.setDelegate(self, queue: coda)
    }

    private var attese: [AVAssetResourceLoadingRequest] = []
    private var alLavoro = false

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource richiesta: AVAssetResourceLoadingRequest) -> Bool {
        if let info = richiesta.contentInformationRequest {
            info.contentType = tipo
            info.contentLength = Int64(lettore.dimensione)
            info.isByteRangeAccessSupported = true
        }
        guard richiesta.dataRequest != nil else {
            richiesta.finishLoading()
            return true
        }
        attese.append(richiesta)
        if !alLavoro {
            alLavoro = true
            coda.async { [weak self] in self?.unPasso() }
        }
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        didCancel richiesta: AVAssetResourceLoadingRequest) {
        attese.removeAll { $0 === richiesta }
    }

    private func unPasso() {
        attese.removeAll { $0.isCancelled || $0.isFinished }
        guard let richiesta = attese.last, let dati = richiesta.dataRequest else {
            alLavoro = false
            return
        }
        let fine = dati.requestsAllDataToEndOfResource
            ? lettore.dimensione
            : min(lettore.dimensione, Int(dati.requestedOffset) + dati.requestedLength)
        let dove = max(Int(dati.currentOffset), Int(dati.requestedOffset))
        if dove >= fine {
            attese.removeLast()
            richiesta.finishLoading()
        } else {
            do {
                let pezzo = try lettore.leggi(da: dove, quanti: min(VideoCifrato.pezzo, fine - dove))
                if pezzo.isEmpty {
                    attese.removeLast()
                    richiesta.finishLoading()
                } else {
                    dati.respond(with: pezzo)
                }
            } catch {
                attese.removeLast()
                richiesta.finishLoading(with: error)
            }
        }
        coda.async { [weak self] in self?.unPasso() }
    }
}

@MainActor
final class Movimento: ObservableObject {

    @Published var muto = true {
        didSet { lettore.isMuted = muto }
    }
    @Published private(set) var inCorso = false
    @Published private(set) var inLoop = false
    @Published private(set) var pronto = false
    @Published private(set) var rotto = false
    @Published private(set) var secondi: Double = 0
    @Published private(set) var durata: Double = 0
    @Published private(set) var inPausa = true

    let lettore = AVQueuePlayer()
    private var fonte: VideoCifrato?
    private var fineGiro: NSObjectProtocol?
    private var orologio: Any?
    private var stato: NSKeyValueObservation?

    init() {
        lettore.isMuted = true
        lettore.actionAtItemEnd = .pause
        lettore.automaticallyWaitsToMinimizeStalling = false
        stato = lettore.observe(\.rate, options: [.initial, .new]) { [weak self] lettore, _ in
            let fermo = lettore.rate == 0
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.inPausa != fermo else { return }
                    self.inPausa = fermo
                }
            }
        }
        orologio = lettore.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak self] t in
            guard t.isNumeric else { return }
            MainActor.assumeIsolated { self?.secondi = t.seconds }
        }
    }

    func chiudi() {
        ferma()
        if let orologio { lettore.removeTimeObserver(orologio) }
        stato?.invalidate()
        stato = nil
        orologio = nil
        if let fineGiro { NotificationCenter.default.removeObserver(fineGiro) }
        fineGiro = nil
        lettore.removeAllItems()
        fonte = nil
    }

    func prepara(pacchetto: Pacchetto, posto: String) async {
        guard !pronto, !rotto else { return }
        let fonte = await Task.detached(priority: .userInitiated) {
            try? VideoCifrato(pacchetto: pacchetto, posto: posto)
        }.value
        guard let fonte, let d = try? await fonte.asset.load(.duration), d.seconds.isFinite,
              (try? await fonte.asset.load(.isPlayable)) == true else {
            rotto = true
            return
        }
        self.fonte = fonte
        durata = d.seconds
        pronto = true
    }

    func unGiro() {
        parti(inAnello: false)
    }

    func inAnello() {
        parti(inAnello: true)
    }

    private func parti(inAnello: Bool) {
        guard let fonte else { return }
        ferma()
        let elemento = AVPlayerItem(asset: fonte.asset)
        elemento.preferredForwardBufferDuration = 4
        fineGiro = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: elemento, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.inLoop {
                    self.lettore.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] fatto in
                        guard fatto else { return }
                        DispatchQueue.main.async {
                            MainActor.assumeIsolated {
                                guard let self, self.inLoop else { return }
                                self.lettore.play()
                            }
                        }
                    }
                } else {
                    self.inCorso = false
                }
            }
        }
        lettore.insert(elemento, after: nil)
        inLoop = inAnello
        inCorso = true
        lettore.play()
    }

    func ferma() {
        lettore.pause()
        if let fineGiro { NotificationCenter.default.removeObserver(fineGiro) }
        fineGiro = nil
        lettore.removeAllItems()
        meta = nil
        ripartire = false
        inLoop = false
        inCorso = false
    }

    private var meta: CMTime?
    private var esatta = false
    private var inViaggio = false

    func vaiA(_ s: Double) {
        insegui(s, esatta: true)
    }

    var adesso: Double {
        if let meta { return meta.seconds }
        let t = lettore.currentTime()
        return t.isNumeric ? t.seconds : secondi
    }

    func fermaPerScorrere() -> Bool {
        let andava = lettore.timeControlStatus == .playing
        if andava { lettore.pause() }
        return andava
    }

    func guarda(_ s: Double) {
        insegui(s, esatta: false)
    }

    func riparti() {
        ripartire = true
        if !inViaggio {
            ripartire = false
            lettore.play()
        }
        objectWillChange.send()
    }

    private var ripartire = false

    private func insegui(_ s: Double, esatta: Bool) {
        meta = CMTime(seconds: min(max(0, s), durata), preferredTimescale: 600)
        self.esatta = esatta
        if !inViaggio { prossimo() }
    }

    private func prossimo() {
        guard let dove = meta else { return }
        let finale = esatta
        inViaggio = true
        let margine = finale ? CMTime.zero : CMTime(value: 1, timescale: 20)
        lettore.currentItem?.cancelPendingSeeks()
        lettore.seek(to: dove, toleranceBefore: margine, toleranceAfter: margine) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.inViaggio = false
                    if let meta = self.meta, meta != dove || self.esatta != finale {
                        self.prossimo()
                        return
                    }
                    if finale {
                        self.meta = nil
                        self.secondi = dove.seconds
                        if self.ripartire { self.ripartire = false; self.lettore.play() }
                    }
                }
            }
        }
    }

    func pausaOVai() {
        if !inPausa {
            lettore.pause()
            return
        }
        if lettore.currentItem == nil {
            parti(inAnello: inLoop)
            return
        }
        if let item = lettore.currentItem, item.duration.isNumeric,
           lettore.currentTime() >= item.duration - CMTime(value: 1, timescale: 30) {
            insegui(0, esatta: true)
            ripartire = true
            return
        }
        lettore.play()
    }
}

struct StratoVideo: UIViewRepresentable {
    let lettore: AVPlayer

    func makeUIView(context: Context) -> Vista {
        let v = Vista()
        v.strato.player = lettore
        v.strato.videoGravity = .resizeAspect
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ v: Vista, context: Context) {
        if v.strato.player !== lettore { v.strato.player = lettore }
    }

    final class Vista: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var strato: AVPlayerLayer { layer as! AVPlayerLayer }
        private var pronto: NSKeyValueObservation?

        override init(frame: CGRect) {
            super.init(frame: frame)
            alpha = 0
            strato.wantsExtendedDynamicRangeContent = true
            pronto = strato.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] strato, _ in
                let si = strato.isReadyForDisplay
                DispatchQueue.main.async {
                    guard let self else { return }
                    UIView.animate(withDuration: si ? 0.22 : 0, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
                        self.alpha = si ? 1 : 0
                    }
                }
            }
        }

        required init?(coder: NSCoder) { nil }
    }
}
