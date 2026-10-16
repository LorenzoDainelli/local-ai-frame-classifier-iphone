import SwiftUI
import UIKit
import VisoreKit

@main
struct VisoreApp: App {
    @StateObject private var stato = StatoVisore()

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
            .environmentObject(stato)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                stato.chiudi()
            }
        }
    }
}

@MainActor
final class StatoVisore: ObservableObject {
    @Published var pacchetto: Pacchetto?
    @Published var errore: String?
    @Published var occupato = false
    @Published var aggiorno = false

    nonisolated static func pulisciGliAvanzi() {
        let cartella = FileManager.default.temporaryDirectory
        let dentro = (try? FileManager.default.contentsOfDirectory(at: cartella, includingPropertiesForKeys: nil)) ?? []
        for file in dentro where ["db", "mov"].contains(file.pathExtension) {
            try? FileManager.default.removeItem(at: file)
        }
        Deposito.scarta(Deposito.interna.deletingLastPathComponent().appendingPathComponent("Pacchetto.in-arrivo"))
    }

    func apri(sorgente: URL?, password: String) {
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
                Portachiavi.salva(password: password, cartella: sorgente)
                await MainActor.run { self.pacchetto = p; self.occupato = false }
            } catch ErroreVisore.passwordSbagliata {
                Portachiavi.dimentica()
                await MainActor.run { self.errore = "La password non apre questo pacchetto. È la stessa del forziere sul computer."; self.occupato = false }
            } catch ErroreVisore.versioneNuova {
                await MainActor.run { self.errore = "Il pacchetto è stato fatto da una versione più nuova. Aggiorna l'app."; self.occupato = false }
            } catch {
                await MainActor.run { self.errore = "Il pacchetto non si apre: va ricopiato dal computer."; self.occupato = false }
            }
        }
    }

    func apriConFaceID() {
        let sorgente = Portachiavi.cartella()
        guard sorgente != nil || Deposito.c_e else { return }
        Task.detached(priority: .userInitiated) {
            guard let password = Portachiavi.leggi() else { return }
            await MainActor.run { self.apri(sorgente: sorgente, password: password) }
        }
    }

    func chiudi() {
        pacchetto = nil
    }
}

struct Sblocco: View {
    @EnvironmentObject var stato: StatoVisore
    @State private var password = ""
    @State private var cartella: URL?
    @State private var scegli = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Visore").font(.largeTitle.bold())
            Button(cartella?.lastPathComponent ?? "Scegli la cartella del pacchetto") { scegli = true }
            SecureField("Password del forziere", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
            Button("Apri") {
                stato.apri(sorgente: cartella ?? Portachiavi.cartella(), password: password)
            }
            .buttonStyle(.borderedProminent)
            .disabled((cartella == nil && !Deposito.c_e) || password.count < 8 || stato.occupato)
            if Portachiavi.c_e || Deposito.c_e {
                Button("Apri con Face ID o codice") { stato.apriConFaceID() }
                    .disabled(stato.occupato)
            }
            if stato.aggiorno { ProgressView("Copio il pacchetto nuovo…") } else if stato.occupato { ProgressView() }
            if let errore = stato.errore { Text(errore).foregroundStyle(.red).multilineTextAlignment(.center) }
        }
        .padding()
        .onAppear { if Portachiavi.c_e || Deposito.c_e { stato.apriConFaceID() } }
        .fileImporter(isPresented: $scegli, allowedContentTypes: [.folder]) { esito in
            if case .success(let url) = esito { cartella = url }
        }
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
