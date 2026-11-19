import CoreLocation
import SwiftUI
import UIKit
import VisoreKit

final class Delegato: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     shouldAllowExtensionPointIdentifier punto: UIApplication.ExtensionPointIdentifier) -> Bool {
        punto != .keyboard
    }

    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool { false }

    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool { false }
}

enum Scudo {
    static let segno = 0x5C0D0

    @MainActor static func copriTutto() {
        for scena in UIApplication.shared.connectedScenes {
            guard let scena = scena as? UIWindowScene else { continue }
            for finestra in scena.windows { copri(finestra) }
        }
    }

    @MainActor static func copri(_ finestra: UIWindow) {
        let nome = NSStringFromClass(type(of: finestra))
        guard finestra.windowLevel == .normal, !nome.contains("Keyboard"), !nome.contains("TextEffects"),
              finestra.viewWithTag(segno) == nil, let sopra = finestra.layer.superlayer else { return }
        let campo = UITextField()
        campo.isSecureTextEntry = true
        campo.isUserInteractionEnabled = false
        campo.tag = segno
        finestra.addSubview(campo)
        campo.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            campo.centerXAnchor.constraint(equalTo: finestra.centerXAnchor),
            campo.centerYAnchor.constraint(equalTo: finestra.centerYAnchor),
        ])
        guard let strato = campo.layer.sublayers?.last else {
            campo.removeFromSuperview()
            return
        }
        sopra.addSublayer(campo.layer)
        strato.addSublayer(finestra.layer)
    }
}

@MainActor
final class Cattura: ObservableObject {
    @Published private(set) var inCorso = false
    private var osservatori: [NSObjectProtocol] = []

    init() {
        let centro = NotificationCenter.default
        osservatori.append(centro.addObserver(forName: UIScene.didActivateNotification, object: nil,
                                              queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                Scudo.copriTutto()
                self?.segui()
                self?.guarda()
            }
        })
        osservatori.append(centro.addObserver(forName: UIWindow.didBecomeVisibleNotification, object: nil,
                                              queue: .main) { [weak self] nota in
            MainActor.assumeIsolated {
                if let finestra = nota.object as? UIWindow { Scudo.copri(finestra) }
                self?.guarda()
            }
        })
        segui()
        guarda()
    }

    private var seguite: Set<ObjectIdentifier> = []

    func segui() {
        for scena in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            guard seguite.insert(ObjectIdentifier(scena)).inserted else { continue }
            scena.registerForTraitChanges([UITraitSceneCaptureState.self]) { [weak self] (_: UIWindowScene, _: UITraitCollection) in
                MainActor.assumeIsolated { self?.guarda() }
            }
        }
    }

    func guarda() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        inCorso = scene.contains { $0.traitCollection.sceneCaptureState == .active }
    }
}

struct CoperturaCattura: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "eye.slash").font(.largeTitle)
                Text("Lo schermo viene registrato o duplicato: il Visore non mostra niente finché non smette.")
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(32)
        }
    }
}

@MainActor
final class Diario: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let posizione = CLLocationManager()
    private var apertoIl: Date?
    private var dove: CLLocationCoordinate2D?

    override init() {
        super.init()
        posizione.delegate = self
        posizione.desiredAccuracy = kCLLocationAccuracyBest
    }

    func inizia() {
        apertoIl = Date()
        dove = nil
        switch posizione.authorizationStatus {
        case .notDetermined: posizione.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: posizione.requestLocation()
        default: break
        }
    }

    func finisci(in cassetto: Cassetto?) {
        guard let inizio = apertoIl else { return }
        apertoIl = nil
        cassetto?.apertura(Ritorno.adesso(inizio), durataS: Int64(max(0, Date().timeIntervalSince(inizio)).rounded()),
                           latitudine: dove?.latitude, longitudine: dove?.longitude)
        dove = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let stato = self.posizione.authorizationStatus
            if self.apertoIl != nil, stato == .authorizedWhenInUse || stato == .authorizedAlways {
                self.posizione.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let ultima = locations.last else { return }
        let c = ultima.coordinate
        Task { @MainActor in if self.apertoIl != nil, self.dove == nil { self.dove = c } }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
