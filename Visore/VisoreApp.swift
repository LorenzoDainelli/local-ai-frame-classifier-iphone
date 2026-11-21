import SwiftUI
import UIKit
import VisoreKit

@main
struct VisoreApp: App {
    @UIApplicationDelegateAdaptor(Delegato.self) private var delegato
    @StateObject private var stato = StatoVisore()
    @StateObject private var cattura = Cattura()
    @StateObject private var diario = Diario()
    @Environment(\.scenePhase) private var fase

    init() { StatoVisore.pulisciGliAvanzi() }

    var body: some Scene {
        WindowGroup {
            Group {
                if let pacchetto = stato.pacchetto, let cassetto = stato.cassetto {
                    Galleria(pacchetto: pacchetto)
                        .environmentObject(cassetto)
                } else {
                    Sblocco()
                }
            }
            .overlay { if fase != .active && stato.pacchetto != nil { Copertura() } }
            .overlay { if cattura.inCorso { CoperturaCattura() } }
            .environmentObject(stato)
            .tint(Tinta.accento)
            .onAppear {
                Deposito.prepara()
                Scudo.copriTutto()
                cattura.segui()
                cattura.guarda()
            }
            .onChange(of: stato.pacchetto != nil) { _, aperto in
                if aperto { diario.inizia() }
            }
            .onChange(of: fase) { _, nuova in
                if nuova == .background {
                    diario.finisci(in: stato.cassetto)
                    stato.chiudi()
                }
                if nuova == .active {
                    Scudo.copriTutto()
                    cattura.guarda()
                    stato.rientro()
                }
            }
        }
    }
}

struct Copertura: View {
    var body: some View {
        ZStack {
            Tinta.fondo.ignoresSafeArea()
            VStack(spacing: 14) {
                Lucchetto(aperto: false)
                Text("Visore").font(Carattere.grande).foregroundStyle(Tinta.ink)
            }
        }
    }
}

enum Attesa {
    static let errori = "visore.password.errori"
    static let fino = "visore.password.attesa"

    static func secondi(dopoErrori n: Int) -> TimeInterval {
        guard n > 0 else { return 0 }
        return min(2 * pow(2, Double(n - 1)), 3600)
    }

    static var finoA: Date? {
        guard let quando = UserDefaults.standard.object(forKey: fino) as? Date, quando > Date() else { return nil }
        return quando
    }

    static func sbagliata() -> Date {
        let d = UserDefaults.standard
        let n = d.integer(forKey: errori) + 1
        let quando = Date().addingTimeInterval(secondi(dopoErrori: n))
        d.set(n, forKey: errori)
        d.set(quando, forKey: fino)
        return quando
    }

    static func giusta() {
        UserDefaults.standard.removeObject(forKey: errori)
        UserDefaults.standard.removeObject(forKey: fino)
    }
}

@MainActor
final class StatoVisore: ObservableObject {
    @Published var pacchetto: Pacchetto?
    @Published var cassetto: Cassetto?
    @Published var errore: String?
    @Published var avviso: String?
    @Published var occupato = false
    @Published var aggiorno = false
    @Published var attesaFino: Date? = Attesa.finoA
    private var faceIDDaChiedere = true

    nonisolated static func pulisciGliAvanzi() {
        let cartella = FileManager.default.temporaryDirectory
        let dentro = (try? FileManager.default.contentsOfDirectory(at: cartella, includingPropertiesForKeys: nil)) ?? []
        for file in dentro where ["db", "mov"].contains(file.pathExtension) {
            try? FileManager.default.removeItem(at: file)
        }
        Deposito.scarta(Deposito.arrivo)
    }

    func apri(sorgente: URL?, password: String, scritta: Bool) {
        if scritta, let fino = Attesa.finoA {
            attesaFino = fino
            return
        }
        occupato = true
        errore = nil
        Task.detached(priority: .userInitiated) {
            var nuova: URL?
            if let sorgente {
                let accesso = sorgente.startAccessingSecurityScopedResource()
                defer { if accesso { sorgente.stopAccessingSecurityScopedResource() } }
                if Deposito.serveAggiornare(da: sorgente) {
                    await MainActor.run { self.aggiorno = true }
                    nuova = try? Deposito.importa(da: sorgente)
                    await MainActor.run { self.aggiorno = false }
                    if nuova == nil && !Deposito.c_e {
                        await MainActor.run { self.errore = "Il pacchetto non si copia: controlla che sia tutto sull'iPhone e riprova."; self.occupato = false }
                        return
                    }
                }
            }
            do {
                let p: Pacchetto
                if let nuova {
                    do {
                        _ = try Pacchetto(cartella: nuova, password: password)
                    } catch {
                        Deposito.scarta(nuova)
                        throw error
                    }
                    try Deposito.sostituisci(con: nuova)
                }
                p = try Pacchetto(cartella: Deposito.interna, password: password)
                if scritta { Portachiavi.salva(password: password, cartella: sorgente) }
                await MainActor.run {
                    Attesa.giusta()
                    self.attesaFino = nil
                    self.avviso = nil
                    self.cassetto = Cassetto(pacchetto: p, dove: Deposito.ritorno(prova: false))
                    self.pacchetto = p
                    self.occupato = false
                }
            } catch ErroreVisore.passwordSbagliata {
                if scritta {
                    await MainActor.run { self.attesaFino = Attesa.sbagliata(); self.occupato = false }
                } else {
                    Portachiavi.dimenticaPassword()
                    await MainActor.run { self.avviso = "Scrivi la password del forziere."; self.occupato = false }
                }
            } catch ErroreVisore.versioneNuova {
                await MainActor.run { self.errore = "Il pacchetto è stato fatto da una versione più nuova. Aggiorna l'app."; self.occupato = false }
            } catch {
                await MainActor.run { self.errore = "Il pacchetto non si apre: va ricopiato dal computer."; self.occupato = false }
            }
        }
    }

    func apriProva(password: String) {
        guard let cartella = Bundle.main.url(forResource: "Prova", withExtension: nil) else { return }
        occupato = true
        errore = nil
        Task.detached(priority: .userInitiated) {
            do {
                let p = try Pacchetto(cartella: cartella, password: password)
                await MainActor.run {
                    self.avviso = nil
                    self.cassetto = Cassetto(pacchetto: p, dove: Deposito.ritorno(prova: true))
                    self.pacchetto = p
                    self.occupato = false
                }
            } catch {
                await MainActor.run { self.errore = "La password della prova è: tre parole che ricordi"; self.occupato = false }
            }
        }
    }

    func rientro() {
        guard pacchetto == nil, faceIDDaChiedere, !occupato else { return }
        faceIDDaChiedere = false
        apriConFaceID()
    }

    func apriConFaceID() {
        guard Deposito.c_e || Portachiavi.cartella() != nil else { return }
        guard Portachiavi.c_e, !Portachiavi.scaduta() else {
            if Portachiavi.c_e {
                Portachiavi.dimenticaPassword()
                avviso = "Sono passati sette giorni, o l'iPhone si è riavviato: scrivi la password del forziere."
            }
            return
        }
        let sorgente = Portachiavi.cartella()
        Task.detached(priority: .userInitiated) {
            let lettura = Portachiavi.leggi()
            await MainActor.run {
                switch lettura {
                case .password(let password):
                    self.apri(sorgente: sorgente, password: password, scritta: false)
                case .fallita:
                    self.avviso = Portachiavi.c_e ? "Face ID non ti ha riconosciuto." : "Troppi Face ID falliti: scrivi la password del forziere."
                case .annullata:
                    break
                case .assente:
                    self.avviso = "Scrivi la password del forziere."
                }
            }
        }
    }

    func chiudi() {
        pacchetto = nil
        cassetto = nil
        Miniature.tutte.sfuma()
        Originali.tutti.sfuma()
        faceIDDaChiedere = true
    }
}

struct Lucchetto: View {
    let aperto: Bool

    var body: some View {
        Image(systemName: aperto ? "lock.open.fill" : "lock.fill")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(Tinta.accento)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 68, height: 68)
            .background(Tinta.alone, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }
}

struct Sblocco: View {
    @EnvironmentObject var stato: StatoVisore
    @State private var password = ""
    @State private var cartella: URL?
    @State private var scegli = false
    @State private var prova = false
    @State private var trema = 0
    @FocusState private var scrive: Bool
    @Environment(\.verticalSizeClass) private var altezza

    var body: some View {
        GeometryReader { g in
            ScrollView {
                Group {
                    if altezza == .compact {
                        HStack(alignment: .center, spacing: 48) {
                            marchio(allineato: .leading)
                            modulo.frame(maxWidth: 360)
                        }
                    } else {
                        VStack(spacing: 26) {
                            marchio(allineato: .center)
                            modulo.frame(maxWidth: 360)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: g.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Tinta.fondo.ignoresSafeArea())
        .onAppear { if UIApplication.shared.applicationState == .active { stato.rientro() } }
        .onChange(of: stato.attesaFino) { _, nuovo in if nuovo != nil { trema += 1 } }
        .fileImporter(isPresented: $scegli, allowedContentTypes: [.folder]) { esito in
            if case .success(let url) = esito { cartella = url }
        }
    }

    private func marchio(allineato: HorizontalAlignment) -> some View {
        VStack(alignment: allineato, spacing: 12) {
            Lucchetto(aperto: stato.pacchetto != nil)
            Text("Visore").font(Carattere.grande).foregroundStyle(Tinta.ink)
            if let scade = Firma.scadenza() {
                Text(Firma.aParole(fino: scade)).font(Carattere.minore).foregroundStyle(Tinta.tenue)
                    .multilineTextAlignment(allineato == .center ? .center : .leading)
            }
        }
    }

    private var modulo: some View {
        VStack(spacing: 12) {
            if !Scudo.attivo {
                VStack(spacing: 8) {
                    Text("Su questa versione di iOS il blocco degli screenshot ha fatto chiudere il Visore, quindi adesso è spento: gli screenshot mostrerebbero le foto.")
                        .font(.system(size: 13)).foregroundStyle(Tinta.male).multilineTextAlignment(.center)
                    Button("Riprova il blocco alla prossima apertura") { Scudo.riprova() }
                        .font(.system(size: 13, weight: .medium))
                }
                .carta(12)
            }
            if prova {
                Text("Prova con 5 foto finte. La password è: tre parole che ricordi")
                    .font(.system(size: 14)).foregroundStyle(Tinta.tenue).multilineTextAlignment(.center)
            } else if !Deposito.c_e || cartella != nil {
                Button { scegli = true } label: {
                    Label(cartella?.lastPathComponent ?? "Scegli la cartella del pacchetto",
                          systemImage: cartella == nil ? "folder" : "folder.fill")
                        .lineLimit(1)
                }
                .buttonStyle(TastoBordo())
            }
            SecureField("", text: $password, prompt: Text("Password del forziere").foregroundStyle(Tinta.tenue))
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit(apri)
                .focused($scrive)
                .multilineTextAlignment(.center)
                .font(.system(size: 16))
                .foregroundStyle(Tinta.ink)
                .frame(height: 50)
                .padding(.horizontal, 14)
                .background(Tinta.superficie, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(scrive ? Tinta.accento : Tinta.lineaForte, lineWidth: scrive ? 1 : 0.5))
                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Tinta.alone, lineWidth: 3)
                    .padding(-3).opacity(scrive ? 1 : 0))
                .animation(Moto.gesto, value: scrive)
                .keyframeAnimator(initialValue: CGFloat(0), trigger: trema) { vista, x in
                    vista.offset(x: x)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(-9, duration: 0.07)
                        LinearKeyframe(9, duration: 0.07)
                        LinearKeyframe(-7, duration: 0.07)
                        LinearKeyframe(7, duration: 0.07)
                        LinearKeyframe(0, duration: 0.07)
                    }
                }
            TastoApri(fino: prova ? nil : stato.attesaFino,
                      lavora: stato.occupato,
                      spento: (!prova && cartella == nil && !Deposito.c_e) || password.count < 8 || stato.occupato,
                      azione: apri)
            if !prova && Portachiavi.c_e && !Portachiavi.scaduta() {
                Button { stato.apriConFaceID() } label: { Label("Apri con Face ID", systemImage: "faceid") }
                    .buttonStyle(TastoBordo())
                    .disabled(stato.occupato)
            }
            if !Deposito.c_e {
                Button(prova ? "Torna al mio pacchetto" : "Prova con le foto finte") {
                    withAnimation(Moto.passo) { prova.toggle() }
                }
                .font(.system(size: 14))
                .foregroundStyle(Tinta.tenue)
                .underline()
                .padding(.top, 2)
                .disabled(stato.occupato)
            }
            if stato.aggiorno {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Copio il pacchetto nuovo…").font(.system(size: 14)).foregroundStyle(Tinta.tenue)
                }
            }
            if let avviso = stato.avviso {
                Text(avviso).font(.system(size: 14)).foregroundStyle(Tinta.tenue).multilineTextAlignment(.center)
                    .transition(.opacity)
            }
            if let errore = stato.errore {
                Text(errore).font(.system(size: 14)).foregroundStyle(Tinta.male).multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(Moto.passo, value: stato.avviso)
        .animation(Moto.passo, value: stato.errore)
    }

    private func apri() {
        guard password.count >= 8, !stato.occupato else {
            trema += 1
            return
        }
        scrive = false
        if prova {
            stato.apriProva(password: password)
            return
        }
        guard cartella != nil || Deposito.c_e else { return }
        stato.apri(sorgente: cartella ?? Portachiavi.cartella(), password: password, scritta: true)
    }
}

struct TastoApri: View {
    let fino: Date?
    let lavora: Bool
    let spento: Bool
    let azione: () -> Void
    @State private var inizio = Date()
    @State private var riempi: CGFloat = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { orologio in
            let resta = fino.map { max(0, $0.timeIntervalSince(orologio.date)) } ?? 0
            let totale = max(fino.map { $0.timeIntervalSince(inizio) } ?? 1, 0.1)
            Button(action: azione) {
                Text(resta > 0 ? "Apri fra \(Int(resta.rounded(.up))) s" : lavora ? "Controllo…" : "Apri")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .buttonStyle(TastoPieno())
            .overlay(alignment: .leading) {
                GeometryReader { g in
                    let parte = resta > 0 ? 1 - resta / totale : (lavora ? riempi : 0)
                    Rectangle().fill(Tinta.suAccento.opacity(0.22))
                        .frame(width: g.size.width * parte)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .allowsHitTesting(false)
            }
            .disabled(spento || resta > 0)
        }
        .onChange(of: fino) { _, _ in inizio = Date() }
        .onChange(of: lavora) { _, si in
            riempi = 0
            if si { withAnimation(.easeOut(duration: 2.4)) { riempi = 0.92 } }
        }
    }
}

enum Sezione: String, CaseIterable, Identifiable {
    case foto, nodi, persone
    var id: String { rawValue }

    var nome: String {
        switch self {
        case .foto: return "Foto"
        case .nodi: return "Nodi"
        case .persone: return "Persone"
        }
    }

    var simbolo: String {
        switch self {
        case .foto: return "photo.on.rectangle"
        case .nodi: return "square.grid.2x2"
        case .persone: return "person.2"
        }
    }
}

@MainActor
final class Interfaccia: ObservableObject {
    @Published var scegliendo = false
    @Published var impostazioni = false
    @Published var cerca = false
}

struct BarraPillola: View {
    @Binding var qui: Sezione
    let ancora: (Sezione) -> Void
    @Namespace private var macchia

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Sezione.allCases) { s in
                Button {
                    if qui == s { ancora(s) } else { withAnimation(Moto.molla) { qui = s } }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: s.simbolo).font(.system(size: 18, weight: .regular))
                            .frame(height: 22)
                        Text(s.nome).font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(qui == s ? Tinta.ink : Tinta.tenue)
                    .frame(width: 76, height: 48)
                    .background {
                        if qui == s {
                            Capsule().fill(Tinta.alone).matchedGeometryEffect(id: "macchia", in: macchia)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(Premuto(quanto: 0.94))
                .accessibilityLabel(s.nome)
                .accessibilityAddTraits(qui == s ? .isSelected : [])
            }
        }
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Tinta.lineaForte, lineWidth: 0.5))
        .shadow(color: Tinta.ombra, radius: 18, y: 8)
        .sensoryFeedback(.selection, trigger: qui)
    }
}

struct Galleria: View {
    let pacchetto: Pacchetto
    @EnvironmentObject var cassetto: Cassetto
    @StateObject private var interfaccia = Interfaccia()
    @StateObject private var annunci = Annunci()
    @State private var qui: Sezione = .foto
    @State private var strade: [Sezione: NavigationPath] = [:]
    @State private var cima: [Sezione: Int] = [:]
    @AppStorage(Giro.chiave) private var giroVisto = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(Sezione.allCases) { s in
                NavigationStack(path: strada(s)) {
                    radice(s)
                        .destinazioni(pacchetto)
                }
                .opacity(qui == s ? 1 : 0)
                .allowsHitTesting(qui == s)
                .accessibilityHidden(qui != s)
            }
            if !interfaccia.scegliendo {
                VStack(spacing: 10) {
                    if let scade = Firma.scadenza(), Firma.giorni(fino: scade) <= 2 {
                        Text(Firma.aParole(fino: scade) + " Rinnovala con AltStore sul portatile.")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Tinta.suAccento)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Tinta.attenzione, in: Capsule())
                            .padding(.horizontal, 24)
                            .allowsHitTesting(false)
                    }
                    BarraPillola(qui: $qui) { s in
                        if strade[s]?.isEmpty == false { strade[s] = NavigationPath() } else { cima[s, default: 0] += 1 }
                    }
                }
                .padding(.bottom, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Moto.passo, value: interfaccia.scegliendo)
        .background(Tinta.fondo.ignoresSafeArea())
        .environmentObject(interfaccia)
        .environmentObject(annunci)
        .modifier(ConAnnunci(annunci: annunci, sopra: interfaccia.scegliendo ? 72 : 76))
        .sheet(isPresented: $interfaccia.impostazioni) {
            Impostazioni(pacchetto: pacchetto).environmentObject(cassetto).foglioStile()
        }
        .fullScreenCover(isPresented: $interfaccia.cerca) {
            NavigationStack {
                Cerca(pacchetto: pacchetto, chiudi: { interfaccia.cerca = false })
                    .destinazioni(pacchetto)
            }
            .environmentObject(cassetto)
            .environmentObject(interfaccia)
            .environmentObject(annunci)
            .modifier(ConAnnunci(annunci: annunci, sopra: 24))
            .tint(Tinta.accento)
        }
        .fullScreenCover(isPresented: Binding(get: { !giroVisto && !interfaccia.impostazioni },
                                              set: { if !$0 { giroVisto = true } })) {
            GiroDiBenvenuto { giroVisto = true }
        }
        .alert("Attenzione", isPresented: Binding(get: { cassetto.guaio != nil }, set: { if !$0 { cassetto.guaio = nil } })) {
            Button("OK") { cassetto.guaio = nil }
        } message: {
            Text(cassetto.guaio ?? "")
        }
    }

    private func strada(_ s: Sezione) -> Binding<NavigationPath> {
        Binding(get: { strade[s] ?? NavigationPath() }, set: { strade[s] = $0 })
    }

    @ViewBuilder
    private func radice(_ s: Sezione) -> some View {
        switch s {
        case .foto:
            GrigliaGiorni(pacchetto: pacchetto, titolo: "Foto", radice: true, cima: cima[.foto] ?? 0)
        case .nodi:
            Albero(pacchetto: pacchetto, cima: cima[.nodi] ?? 0)
        case .persone:
            Persone(pacchetto: pacchetto, cima: cima[.persone] ?? 0)
        }
    }
}

struct AzioniDiTesta: View {
    @EnvironmentObject var interfaccia: Interfaccia

    var body: some View {
        HStack(spacing: 8) {
            Tondo(simbolo: "magnifyingglass", etichetta: "Cerca") { interfaccia.cerca = true }
            Tondo(simbolo: "gearshape", etichetta: "Impostazioni") { interfaccia.impostazioni = true }
        }
    }
}

extension View {
    func destinazioni(_ pacchetto: Pacchetto) -> some View {
        navigationDestination(for: Nodo.self) { NodoVista(pacchetto: pacchetto, nodo: $0) }
            .navigationDestination(for: Persona.self) { PersonaVista(pacchetto: pacchetto, persona: $0) }
            .navigationDestination(for: Coppia.self) { CoppiaVista(pacchetto: pacchetto, coppia: $0) }
            .navigationDestination(for: TutteLeRaccolte.self) { _ in RaccolteVista(pacchetto: pacchetto) }
            .navigationDestination(for: QualeRaccolta.self) { RaccoltaVista(pacchetto: pacchetto, quale: $0) }
    }
}
