import SwiftUI

struct PassoDelGiro: Identifiable {
    let id: Int
    let simbolo: String
    let titolo: String
    let testo: String
}

enum Giro {
    static let chiave = "visore.giro.visto"

    static let passi: [PassoDelGiro] = [
        PassoDelGiro(id: 0, simbolo: "eye",
                     titolo: "Il tuo archivio, da guardare",
                     testo: "Qui le foto si guardano soltanto: niente si cancella e niente si cambia. "
                         + "Quello che conta lo decide il PC."),
        PassoDelGiro(id: 1, simbolo: "square.grid.3x3",
                     titolo: "Una griglia di giorni",
                     testo: "Scorri per giorni, dal più recente. Pizzica per vedere più foto o più grandi. "
                         + "Tocca una foto per aprirla."),
        PassoDelGiro(id: 2, simbolo: "livephoto",
                     titolo: "Le live photo",
                     testo: "Tocca la foto: si muove una volta. Appoggia il dito e scendi piano: resta accesa "
                         + "anche senza dito. Tocca di nuovo per spegnerla."),
        PassoDelGiro(id: 3, simbolo: "arrow.down.to.line",
                     titolo: "Chiudere e vedere di più",
                     testo: "Giù di scatto chiude la foto. Su mostra i comandi e le informazioni. "
                         + "Il gesto conta solo quando arriva in fondo: mollando prima non succede niente."),
        PassoDelGiro(id: 4, simbolo: "heart",
                     titolo: "Preferiti e raccolte",
                     testo: "Due tocchi sulla foto mettono il cuore. Con «Scegli» nella griglia prendi più foto "
                         + "e fai una raccolta. Tutto torna al PC col cavo."),
        PassoDelGiro(id: 5, simbolo: "square.stack",
                     titolo: "Nodi, Persone, Cerca",
                     testo: "In basso: le categorie del PC, le persone riconosciute e la ricerca. "
                         + "Tocca di nuovo la sezione in cui sei per tornare in cima."),
        PassoDelGiro(id: 6, simbolo: "lock",
                     titolo: "Si chiude da solo",
                     testo: "Appena esci o cambi app il Visore si chiude, e al rientro chiede Face ID. "
                         + "Se lo schermo viene registrato, si copre. Il giro si rivede dalle impostazioni."),
    ]
}

struct GiroDiBenvenuto: View {
    let finito: () -> Void
    @State private var qui = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Salta", action: finito)
                    .padding()
            }
            TabView(selection: $qui) {
                ForEach(Giro.passi) { passo in
                    VStack(spacing: 22) {
                        Spacer()
                        Image(systemName: passo.simbolo)
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(.tint)
                        Text(passo.titolo)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(passo.testo)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 460)
                        Spacer()
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .tag(passo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            Button {
                if qui < Giro.passi.count - 1 {
                    withAnimation { qui += 1 }
                } else {
                    finito()
                }
            } label: {
                Text(qui < Giro.passi.count - 1 ? "Avanti" : "Inizia")
                    .font(.headline)
                    .frame(maxWidth: 420)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
