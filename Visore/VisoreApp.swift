import SwiftUI
import UIKit
import VisoreKit

@main
struct VisoreApp: App {
    @StateObject private var stato = StatoVisore()

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

    func apri(cartella: URL, password: String) {
        occupato = true
        errore = nil
        Task.detached(priority: .userInitiated) {
            let accesso = cartella.startAccessingSecurityScopedResource()
            defer { if accesso { cartella.stopAccessingSecurityScopedResource() } }
            do {
                let p = try Pacchetto(cartella: cartella, password: password)
                Portachiavi.salva(password: password, cartella: cartella)
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
        guard let cartella = Portachiavi.cartella() else { return }
        Task.detached(priority: .userInitiated) {
            guard let password = Portachiavi.leggi() else { return }
            await MainActor.run { self.apri(cartella: cartella, password: password) }
        }
    }

    func chiudi() { pacchetto = nil }
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
                if let cartella { stato.apri(cartella: cartella, password: password) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(cartella == nil || password.count < 8 || stato.occupato)
            if Portachiavi.c_e {
                Button("Apri con Face ID o codice") { stato.apriConFaceID() }
                    .disabled(stato.occupato)
            }
            if stato.occupato { ProgressView() }
            if let errore = stato.errore { Text(errore).foregroundStyle(.red).multilineTextAlignment(.center) }
        }
        .padding()
        .onAppear { if Portachiavi.c_e { stato.apriConFaceID() } }
        .fileImporter(isPresented: $scegli, allowedContentTypes: [.folder]) { esito in
            if case .success(let url) = esito { cartella = url }
        }
    }
}

struct Galleria: View {
    let pacchetto: Pacchetto
    @State private var scatti: [Scatto] = []
    @State private var cerca = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                    ForEach(scatti) { s in
                        NavigationLink { Dettaglio(pacchetto: pacchetto, scatto: s) } label: {
                            Miniatura(pacchetto: pacchetto, posto: s.mini ?? s.posto)
                        }
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
        scatti = (try? testo.isEmpty ? pacchetto.archivio.scatti() : pacchetto.archivio.cerca(testo)) ?? []
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
