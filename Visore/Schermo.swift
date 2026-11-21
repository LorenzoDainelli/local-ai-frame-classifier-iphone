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
    static let inProva = "visore.scudo.in.prova"
    static let saltato = "visore.scudo.saltato"
    @MainActor private static var campi: [ObjectIdentifier: UITextField] = [:]
    @MainActor private static var controllato = false

    static var attivo: Bool { !UserDefaults.standard.bool(forKey: saltato) }

    @MainActor static func copriTutto() {
        for scena in UIApplication.shared.connectedScenes {
            guard let scena = scena as? UIWindowScene else { continue }
            for finestra in scena.windows { copri(finestra) }
        }
    }

    @MainActor static func copri(_ finestra: UIWindow) {
        let d = UserDefaults.standard
        if !controllato {
            controllato = true
            if d.bool(forKey: inProva) {
                d.set(false, forKey: inProva)
                d.set(true, forKey: saltato)
            }
        }
        guard attivo else { return }
        let nome = NSStringFromClass(type(of: finestra))
        let chi = ObjectIdentifier(finestra)
        guard finestra.windowLevel == .normal, !nome.contains("Keyboard"), !nome.contains("TextEffects"),
              campi[chi] == nil, let sopra = finestra.layer.superlayer else { return }
        let campo = UITextField(frame: .zero)
        campo.isSecureTextEntry = true
        campo.isUserInteractionEnabled = false
        guard let strato = campo.layer.sublayers?.last else { return }
        d.set(true, forKey: inProva)
        d.synchronize()
        campi[chi] = campo
        sopra.addSublayer(campo.layer)
        strato.addSublayer(finestra.layer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UserDefaults.standard.set(false, forKey: inProva)
        }
    }

    static func riprova() {
        let d = UserDefaults.standard
        d.set(false, forKey: saltato)
        d.set(false, forKey: inProva)
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
            Tinta.fondo.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Tinta.accento)
                    .frame(width: 68, height: 68)
                    .background(Tinta.alone, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text("Schermo coperto").font(Carattere.titoletto).foregroundStyle(Tinta.ink)
                Text("Lo schermo viene registrato o duplicato: il Visore non mostra niente finché non smette.")
                    .font(.system(size: 15)).foregroundStyle(Tinta.attenuato)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
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
