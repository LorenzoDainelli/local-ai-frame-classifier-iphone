import SwiftUI
import UIKit
import VisoreKit

@MainActor
final class Cassetto: ObservableObject {
    @Published private(set) var cuori: Set<String> = []
    @Published private(set) var raccolte: [Raccolta] = []
    @Published private(set) var versione = 0
    @Published var guaio: String?
    @Published var aperta = false
    @Published private(set) var diarioDal: String?
    private(set) var viste: Set<Int64> = []
    private let ritorno: Ritorno?

    static let nonSalvato = "Non riesco a salvare sull'iPhone: forse è pieno. Quello che avevi già messo da parte è al sicuro."

    init(pacchetto: Pacchetto, dove: URL) {
        var guaio: String?
        do {
            let r = try pacchetto.ritorno(in: dove)
            ritorno = r
            guaio = r.guaio
        } catch {
            ritorno = nil
            guaio = "Cuori e raccolte oggi non si aprono: l'iPhone è pieno, oppure il loro file non si sposta. "
                + "Le foto ci sono tutte."
        }
        self.guaio = guaio
        rileggi()
    }

    func haIlCuore(_ s: Scatto) -> Bool { cuori.contains(s.impronta) }

    func raccolta(_ numero: Int64) -> Raccolta? { raccolte.first { $0.numero == numero } }

    @discardableResult
    func cuore(_ impronte: [String], acceso: Bool) -> Bool {
        fai { try acceso ? $0.metti(impronte) : $0.togli(impronte) }
    }

    func nuova(_ nome: String, impronte: [String]) -> Int64? {
        var numero: Int64?
        fai { numero = try $0.nuovaRaccolta(nome, impronte: impronte) }
        return numero
    }

    @discardableResult
    func aggiungi(_ impronte: [String], a numero: Int64) -> Bool {
        fai { try $0.aggiungi(impronte, a: numero) }
    }

    @discardableResult
    func togli(_ impronte: [String], da numero: Int64) -> Bool {
        fai { try $0.togli(impronte, da: numero) }
    }

    func rinomina(_ numero: Int64, in nome: String) {
        fai { try $0.rinomina(numero, in: nome) }
    }

    func butta(_ numero: Int64) {
        fai { try $0.butta(numero) }
    }

    func vista(_ id: Int64) {
        viste.insert(id)
    }

    func apertura(_ apertoIl: String, durataS: Int64, latitudine: Double?, longitudine: Double?) {
        let quante = Int64(viste.count)
        viste = []
        guard let ritorno else { return }
        try? ritorno.apertura(apertoIl, durataS: durataS, latitudine: latitudine, longitudine: longitudine,
                              quanteFoto: quante)
        diarioDal = ritorno.diarioDal()
    }

    @discardableResult
    private func fai(_ azione: (Ritorno) throws -> Void) -> Bool {
        guard let ritorno else {
            guaio = Cassetto.nonSalvato
            return false
        }
        var riuscito = true
        do {
            try azione(ritorno)
        } catch ErroreRitorno.nomeVuoto {
            guaio = "Una raccolta ha bisogno di un nome."
            riuscito = false
        } catch {
            guaio = Cassetto.nonSalvato
            riuscito = false
        }
        rileggi()
        return riuscito
    }

    private func rileggi() {
        cuori = ritorno?.cuori() ?? []
        raccolte = ritorno?.raccolte() ?? []
        diarioDal = ritorno?.diarioDal()
        versione += 1
    }
}

struct QualeRaccolta: Hashable {
    let numero: Int64?
}

struct TutteLeRaccolte: Hashable {}

struct MenuRaccolta<Etichetta: View>: View {
    @EnvironmentObject var cassetto: Cassetto
    let impronte: () -> [String]
    let fatto: () -> Void
    @ViewBuilder let etichetta: () -> Etichetta
    @State private var chiedeNome = false
    @State private var nome = ""
    @State private var daMettere: [String] = []

    var body: some View {
        Menu {
            Button {
                daMettere = impronte()
                nome = ""
                chiedeNome = true
            } label: { Label("Nuova raccolta…", systemImage: "plus") }
            if !cassetto.raccolte.isEmpty {
                Section("Aggiungi a") {
                    ForEach(cassetto.raccolte) { r in
                        Button(r.nome) {
                            if cassetto.aggiungi(impronte(), a: r.numero) { fatto() }
                        }
                    }
                }
            }
        } label: { etichetta() }
        .alert("Nuova raccolta", isPresented: $chiedeNome) {
            TextField("Nome", text: $nome)
            Button("Crea") {
                if cassetto.nuova(nome, impronte: daMettere) != nil { fatto() }
            }
            .disabled(nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Annulla", role: .cancel) {}
        } message: {
            Text(daMettere.count == 1 ? "Con questa foto." : "Con \(Testi.numero(daMettere.count)) foto.")
        }
    }
}

struct CopertinaRaccolta: View {
    let pacchetto: Pacchetto
    let impronte: [String]
    let lato: CGFloat
    let simbolo: String
    @State private var immagine: UIImage?
    @Environment(\.displayScale) private var scala

    var body: some View {
        ZStack {
            if let immagine {
                Image(uiImage: immagine).resizable().scaledToFill()
            } else {
                Color(white: 0.12)
                Image(systemName: simbolo).font(.title2).foregroundStyle(.secondary)
            }
        }
        .frame(width: lato, height: lato)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: impronte) {
            guard let s = (try? pacchetto.archivio.scatti(filtro: Filtro(impronte: impronte), limite: 1))?.first else {
                immagine = nil
                return
            }
            let posto = s.mini ?? s.posto
            immagine = Miniature.tutte.pronta(posto)
            if immagine == nil { immagine = await Miniature.tutte.carica(pacchetto, posto, lato: lato * scala) }
        }
    }
}

struct RigaRaccolta: View {
    let pacchetto: Pacchetto
    let nome: String
    let impronte: [String]
    let simbolo: String

    var body: some View {
        HStack(spacing: 14) {
            CopertinaRaccolta(pacchetto: pacchetto, impronte: impronte, lato: 64, simbolo: simbolo)
            VStack(alignment: .leading, spacing: 3) {
                Text(nome).font(.headline).lineLimit(2)
                Text(impronte.count == 1 ? "1 foto" : "\(Testi.numero(impronte.count)) foto")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}

struct RaccolteVista: View {
    let pacchetto: Pacchetto
    @EnvironmentObject var cassetto: Cassetto
    @State private var daButtare: Raccolta?
    @State private var daRinominare: Raccolta?
    @State private var nome = ""

    var body: some View {
        List {
            NavigationLink(value: QualeRaccolta(numero: nil)) {
                RigaRaccolta(pacchetto: pacchetto, nome: "Preferiti", impronte: Array(cassetto.cuori).sorted(),
                             simbolo: "heart")
            }
            Section {
                ForEach(cassetto.raccolte) { r in
                    NavigationLink(value: QualeRaccolta(numero: r.numero)) {
                        RigaRaccolta(pacchetto: pacchetto, nome: r.nome, impronte: r.impronte,
                                     simbolo: "rectangle.stack")
                    }
                    .swipeActions {
                        Button("Elimina", role: .destructive) { daButtare = r }
                        Button("Rinomina") {
                            nome = r.nome
                            daRinominare = r
                        }
                    }
                    .contextMenu {
                        Button {
                            nome = r.nome
                            daRinominare = r
                        } label: { Label("Rinomina", systemImage: "pencil") }
                        Button(role: .destructive) { daButtare = r } label: { Label("Elimina", systemImage: "trash") }
                    }
                }
            } header: {
                Text("Le tue raccolte")
            } footer: {
                if cassetto.raccolte.isEmpty {
                    Text("Per farne una: nella griglia premi «Scegli», tocca le foto e poi il tasto delle raccolte in basso.")
                }
            }
        }
        .navigationTitle("Raccolte")
        .confirmationDialog(daButtare.map { "Eliminare «\($0.nome)»?" } ?? "",
                            isPresented: Binding(get: { daButtare != nil }, set: { if !$0 { daButtare = nil } }),
                            titleVisibility: .visible, presenting: daButtare) { r in
            Button("Elimina la raccolta", role: .destructive) { cassetto.butta(r.numero) }
        } message: { _ in
            Text("Le foto restano tutte: si toglie solo la raccolta, anche dal computer al prossimo travaso.")
        }
        .alert("Rinomina", isPresented: Binding(get: { daRinominare != nil }, set: { if !$0 { daRinominare = nil } }),
               presenting: daRinominare) { r in
            TextField("Nome", text: $nome)
            Button("Salva") { cassetto.rinomina(r.numero, in: nome) }
                .disabled(nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Annulla", role: .cancel) {}
        }
    }
}

struct RaccoltaVista: View {
    let pacchetto: Pacchetto
    let quale: QualeRaccolta
    @EnvironmentObject var cassetto: Cassetto
    @State private var mostrate: [String]?

    var body: some View {
        Group {
            if let mostrate {
                GrigliaGiorni(pacchetto: pacchetto, filtro: Filtro(impronte: mostrate), raccolta: quale.numero,
                              vuota: quale.numero == nil
                                  ? "Nessun preferito. Tocca due volte una foto, o il cuore in basso, per metterla qui."
                                  : "Questa raccolta è vuota.")
                    .id(mostrate)
            } else {
                Color.clear
            }
        }
        .navigationTitle(titolo)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if mostrate == nil { mostrate = attuali } }
        .onChange(of: cassetto.versione) { _, _ in if !cassetto.aperta { mostrate = attuali } }
        .onChange(of: cassetto.aperta) { _, si in if !si, mostrate != attuali { mostrate = attuali } }
    }

    private var titolo: String {
        guard let numero = quale.numero else { return "Preferiti" }
        return cassetto.raccolta(numero)?.nome ?? "Raccolta"
    }

    private var attuali: [String] {
        guard let numero = quale.numero else { return Array(cassetto.cuori).sorted() }
        return cassetto.raccolta(numero)?.impronte ?? []
    }
}

struct CuoreGrande: View {
    let colpi: Int

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 110))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 12)
            .allowsHitTesting(false)
            .phaseAnimator([0, 1, 2], trigger: colpi) { v, fase in
                v.scaleEffect(fase == 0 ? 0.5 : fase == 1 ? 1 : 1.15)
                    .opacity(fase == 1 ? 1 : 0)
            } animation: { fase in
                fase == 1 ? .spring(duration: 0.3, bounce: 0.45) : .easeOut(duration: 0.35).delay(fase == 2 ? 0.35 : 0)
            }
    }
}
