import SwiftUI
import UIKit
import VisoreKit

@main
struct VisoreApp: App {
    @StateObject private var stato = StatoVisore()
    @Environment(\.scenePhase) private var fase

    init() { StatoVisore.pulisciGliAvanzi() }

    var body: some Scene {
        WindowGroup {
            Group {
                if let pacchetto = stato.pacchetto {
                    Galleria(pacchetto: pacchetto)
                } else {
                    Sblocco()
                }
            }
            .overlay { if fase != .active && stato.pacchetto != nil { Copertura() } }
            .environmentObject(stato)
            .preferredColorScheme(.dark)
            .onChange(of: fase) { _, nuova in
                if nuova == .background { stato.chiudi() }
                if nuova == .active { stato.rientro() }
            }
        }
    }
}

struct Copertura: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Visore").font(.largeTitle.bold()).foregroundStyle(.white.opacity(0.6))
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
        Deposito.scarta(Deposito.interna.deletingLastPathComponent().appendingPathComponent("Pacchetto.in-arrivo"))
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
                await MainActor.run { self.avviso = nil; self.pacchetto = p; self.occupato = false }
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
        faceIDDaChiedere = true
    }
}

struct Sblocco: View {
    @EnvironmentObject var stato: StatoVisore
    @State private var password = ""
    @State private var cartella: URL?
    @State private var scegli = false
    @State private var prova = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Visore").font(.largeTitle.bold())
            if prova {
                Text("Prova con 5 foto finte. La password è: tre parole che ricordi")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else if !Deposito.c_e || cartella != nil {
                Button(cartella?.lastPathComponent ?? "Scegli la cartella del pacchetto") { scegli = true }
            }
            SecureField("Password del forziere", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit(apri)
            TastoApri(fino: prova ? nil : stato.attesaFino,
                      spento: (!prova && cartella == nil && !Deposito.c_e) || password.count < 8 || stato.occupato,
                      azione: apri)
            if !Deposito.c_e {
                Button(prova ? "Torna al mio pacchetto" : "Prova con le foto finte") { prova.toggle() }
                    .disabled(stato.occupato)
            }
            if !prova && Portachiavi.c_e && !Portachiavi.scaduta() {
                Button("Apri con Face ID") { stato.apriConFaceID() }
                    .disabled(stato.occupato)
            }
            if stato.aggiorno { ProgressView("Copio il pacchetto nuovo…") } else if stato.occupato { ProgressView() }
            if let avviso = stato.avviso { Text(avviso).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            if let errore = stato.errore { Text(errore).foregroundStyle(.red).multilineTextAlignment(.center) }
        }
        .padding()
        .onAppear { if UIApplication.shared.applicationState == .active { stato.rientro() } }
        .fileImporter(isPresented: $scegli, allowedContentTypes: [.folder]) { esito in
            if case .success(let url) = esito { cartella = url }
        }
    }

    private func apri() {
        guard password.count >= 8, !stato.occupato else { return }
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
    let spento: Bool
    let azione: () -> Void
    @State private var inizio = Date()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { orologio in
            let resta = fino.map { max(0, $0.timeIntervalSince(orologio.date)) } ?? 0
            let totale = max(fino.map { $0.timeIntervalSince(inizio) } ?? 1, 0.1)
            Button(action: azione) {
                Text(resta > 0 ? "Apri · \(Int(resta.rounded(.up)))" : "Apri")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(alignment: .leading) {
                        GeometryReader { g in
                            Rectangle().fill(.white.opacity(0.18))
                                .frame(width: resta > 0 ? g.size.width * (1 - resta / totale) : 0)
                        }
                    }
            }
            .buttonStyle(.borderedProminent)
            .disabled(spento || resta > 0)
        }
        .onChange(of: fino) { _, _ in inizio = Date() }
    }
}

struct Galleria: View {
    let pacchetto: Pacchetto
    @State private var scatti: [Scatto] = []
    @State private var cerca = ""
    @State private var finiti = false
    private static let pagina = 300

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                    ForEach(scatti) { s in
                        NavigationLink { Dettaglio(pacchetto: pacchetto, scatto: s) } label: {
                            Miniatura(pacchetto: pacchetto, posto: s.mini ?? s.posto)
                        }
                        .onAppear { if s.id == scatti.last?.id { altri() } }
                    }
                }
            }
            .navigationTitle("\(pacchetto.carta.quantiScatti) scatti")
            .toolbar {
                NavigationLink("Albero") { Albero(pacchetto: pacchetto, genitore: nil) }
            }
            .searchable(text: $cerca)
            .onChange(of: cerca) { _, nuovo in carica(nuovo) }
            .onAppear { carica("") }
        }
    }

    private func carica(_ testo: String) {
        if testo.isEmpty {
            scatti = (try? pacchetto.archivio.scatti(limite: Galleria.pagina)) ?? []
            finiti = scatti.count < Galleria.pagina
        } else {
            scatti = (try? pacchetto.archivio.cerca(testo)) ?? []
            finiti = true
        }
    }

    private func altri() {
        guard !finiti, cerca.isEmpty else { return }
        let nuovi = (try? pacchetto.archivio.scatti(limite: Galleria.pagina, dopo: scatti.count)) ?? []
        finiti = nuovi.count < Galleria.pagina
        scatti += nuovi
    }
}

struct Miniatura: View {
    let pacchetto: Pacchetto
    let posto: String
    @State private var immagine: UIImage?

    var body: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay { if let immagine { Image(uiImage: immagine).resizable().scaledToFill() } }
            .clipped()
            .task(id: posto) {
                let p = pacchetto, dove = posto
                immagine = await Task.detached { (try? p.apri(dove)).flatMap(UIImage.init(data:)) }.value
            }
    }
}
