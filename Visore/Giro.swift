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
                     testo: "Tieni il dito premuto su una live photo: si muove finché tieni. "
                         + "Un tocco, invece, nasconde e rimostra tutti i comandi."),
        PassoDelGiro(id: 3, simbolo: "arrow.down.to.line",
                     titolo: "Chiudere e vedere di più",
                     testo: "In basso ci sono le miniature di prima e dopo: toccane una per saltarci. "
                         + "Giù di scatto chiude la foto, su mostra le informazioni."),
        PassoDelGiro(id: 4, simbolo: "heart",
                     titolo: "Preferiti e raccolte",
                     testo: "Due tocchi sulla foto mettono il cuore. Con «Scegli» nella griglia prendi più foto "
                         + "e fai una raccolta. Tutto torna al PC col cavo."),
        PassoDelGiro(id: 5, simbolo: "square.stack",
                     titolo: "Scatti, Nodi, Persone",
                     testo: "La barra in basso porta agli scatti, alle categorie del PC e alle persone. "
                         + "La lente in alto cerca. Tocca di nuovo la sezione in cui sei per tornare in cima."),
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Tinta.tenue)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
            }
            TabView(selection: $qui) {
                ForEach(Giro.passi) { passo in
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(systemName: passo.simbolo)
                                .font(.system(size: 34, weight: .regular))
                                .foregroundStyle(Tinta.accento)
                                .frame(width: 84, height: 84)
                                .background(Tinta.alone, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .symbolEffect(.bounce, value: qui == passo.id)
                            Text(passo.titolo)
                                .font(Carattere.titolo)
                                .foregroundStyle(Tinta.ink)
                                .multilineTextAlignment(.center)
                            Text(passo.testo)
                                .font(.system(size: 16))
                                .foregroundStyle(Tinta.attenuato)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .frame(maxWidth: 440)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                    .tag(passo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 6) {
                ForEach(Giro.passi) { p in
                    Capsule()
                        .fill(p.id == qui ? Tinta.accento : Tinta.lineaForte)
                        .frame(width: p.id == qui ? 22 : 7, height: 7)
                }
            }
            .animation(Moto.molla, value: qui)
            .padding(.bottom, 18)
            Button {
                if qui < Giro.passi.count - 1 {
                    withAnimation(Moto.scena) { qui += 1 }
                } else {
                    finito()
                }
            } label: {
                Text(qui < Giro.passi.count - 1 ? "Avanti" : "Inizia")
                    .contentTransition(.opacity)
            }
            .buttonStyle(TastoPieno())
            .frame(maxWidth: 420)
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
        .background(Tinta.fondo.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: qui)
    }
}
