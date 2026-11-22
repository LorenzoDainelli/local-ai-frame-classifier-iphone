import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

final class DitoRiconoscitore: UIGestureRecognizer {
    var inizio: () -> Void = {}
    var decide: (CGSize) -> Bool = { _ in false }
    var cambia: (CGSize) -> Void = { _ in }
    var fine: (CGSize, CGSize, Bool) -> Void = { _, _, _ in }
    var annulla: () -> Void = {}

    private var partenza: CGPoint = .zero
    private var ultimo: (CGPoint, TimeInterval) = (.zero, 0)
    private var velocita: CGSize = .zero
    private var preso = false
    private var chiuso = false

    private func punto(_ touches: Set<UITouch>) -> CGPoint {
        touches.first?.location(in: view?.window) ?? .zero
    }

    private func spostamento(_ p: CGPoint) -> CGSize {
        CGSize(width: p.x - partenza.x, height: p.y - partenza.y)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        let dita = event.allTouches?.count ?? touches.count
        if dita > 1 || numberOfTouches > 1 {
            lascia()
            return
        }
        partenza = punto(touches)
        ultimo = (partenza, touches.first?.timestamp ?? 0)
        velocita = .zero
        preso = false
        chiuso = false
        inizio()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard !chiuso else { return }
        let p = punto(touches)
        let t = touches.first?.timestamp ?? 0
        let dt = t - ultimo.1
        if dt > 0 {
            velocita = CGSize(width: (p.x - ultimo.0.x) / dt, height: (p.y - ultimo.0.y) / dt)
        }
        ultimo = (p, t)
        let s = spostamento(p)
        if !preso {
            guard max(abs(s.width), abs(s.height)) > Gesti.primoMovimento else { return }
            if decide(s) {
                preso = true
                state = .began
            } else {
                chiuso = true
                annulla()
                state = .failed
                return
            }
        }
        cambia(s)
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard !chiuso else { return }
        chiuso = true
        fine(spostamento(punto(touches)), velocita, preso)
        state = preso ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        lascia()
    }

    private func lascia() {
        guard !chiuso else { return }
        chiuso = true
        annulla()
        state = preso ? .cancelled : .failed
    }

    override func reset() {
        super.reset()
        preso = false
        chiuso = false
    }
}

struct Dito: UIGestureRecognizerRepresentable {
    var inizio: () -> Void
    var decide: (CGSize) -> Bool
    var cambia: (CGSize) -> Void
    var fine: (CGSize, CGSize, Bool) -> Void
    var annulla: () -> Void

    func makeUIGestureRecognizer(context: Context) -> DitoRiconoscitore {
        let r = DitoRiconoscitore()
        r.cancelsTouchesInView = false
        r.delaysTouchesBegan = false
        r.delaysTouchesEnded = false
        r.delegate = context.coordinator
        aggiorna(r)
        return r
    }

    func updateUIGestureRecognizer(_ r: DitoRiconoscitore, context: Context) {
        aggiorna(r)
    }

    private func aggiorna(_ r: DitoRiconoscitore) {
        r.inizio = inizio
        r.decide = decide
        r.cambia = cambia
        r.fine = fine
        r.annulla = annulla
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Accordo { Accordo() }

    final class Accordo: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith altro: UIGestureRecognizer) -> Bool {
            altro is UIPinchGestureRecognizer
        }
    }
}
