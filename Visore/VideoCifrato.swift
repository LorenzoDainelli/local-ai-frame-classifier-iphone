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

    let lettore = AVQueuePlayer()
    private var fonte: VideoCifrato?
    private var anello: AVPlayerLooper?
    private var fineGiro: NSObjectProtocol?
    private var orologio: Any?

    init() {
        lettore.isMuted = true
        lettore.actionAtItemEnd = .pause
        orologio = lettore.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak self] t in
            guard t.isNumeric else { return }
            MainActor.assumeIsolated { self?.secondi = t.seconds }
        }
    }

    func chiudi() {
        ferma()
        if let orologio { lettore.removeTimeObserver(orologio) }
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
        guard let fonte else { return }
        ferma()
        let elemento = AVPlayerItem(asset: fonte.asset)
        fineGiro = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: elemento, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.inLoop else { return }
                self.inCorso = false
            }
        }
        lettore.insert(elemento, after: nil)
        inCorso = true
        lettore.play()
    }

    func inAnello() {
        guard let fonte else { return }
        ferma()
        anello = AVPlayerLooper(player: lettore, templateItem: AVPlayerItem(asset: fonte.asset))
        inLoop = true
        inCorso = true
        lettore.play()
    }

    func ferma() {
        lettore.pause()
        anello?.disableLooping()
        anello = nil
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

    var inPausa: Bool { lettore.timeControlStatus != .playing }

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
        if lettore.timeControlStatus == .playing { lettore.pause() } else { lettore.play() }
        objectWillChange.send()
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
    }
}
