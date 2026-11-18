import SwiftUI
import VisoreKit

struct Albero: View {
    let pacchetto: Pacchetto
    let genitore: Nodo?
    @State private var figli: [Nodo] = []
    @State private var soloQui = false

    var body: some View {
        List {
            if let genitore {
                Section {
                    Toggle("Solo qui", isOn: $soloQui)
                    NavigationLink("Vedi \(soloQui ? genitore.quanti : genitore.quantiColRamo) scatti") {
                        GrigliaGiorni(pacchetto: pacchetto,
                                      elenco: Elenco { [pacchetto, soloQui] quanti, dopo in
                                          (try? pacchetto.archivio.scatti(nodo: genitore.id, soloQui: soloQui,
                                                                          limite: quanti, dopo: dopo)) ?? []
                                      })
                            .navigationTitle(genitore.nome)
                    }
                }
            }
            ForEach(figli) { nodo in
                NavigationLink {
                    Albero(pacchetto: pacchetto, genitore: nodo)
                } label: {
                    HStack {
                        Text(nodo.nome)
                        Spacer()
                        Text("\(soloQui ? nodo.quanti : nodo.quantiColRamo)").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(genitore?.nome ?? "Albero")
        .onAppear { figli = (try? pacchetto.archivio.nodi(figliDi: genitore?.id)) ?? [] }
    }
}
