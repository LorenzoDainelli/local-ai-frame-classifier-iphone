import SwiftUI
import VisoreKit

struct Copertina: View {
    let pacchetto: Pacchetto
    let nodo: Nodo
    let lato: CGFloat
    @State private var immagine: UIImage?
    @Environment(\.displayScale) private var scala

    var body: some View {
        ZStack {
            if let immagine {
                Image(uiImage: immagine).resizable().scaledToFill()
            } else {
                Luccichio()
            }
        }
        .frame(width: lato, height: lato)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: nodo.id) {
            guard let s = try? pacchetto.archivio.copertina(nodo: nodo.id) else { return }
            let posto = s.mini ?? s.posto
            immagine = Miniature.tutte.pronta(posto)
            if immagine == nil { immagine = await Miniature.tutte.carica(pacchetto, posto, lato: lato * scala) }
        }
    }
}

struct Scheda: View {
    let pacchetto: Pacchetto
    let nodo: Nodo
    let lato: CGFloat
    let numero: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Copertina(pacchetto: pacchetto, nodo: nodo, lato: lato)
            Text(nodo.nome).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(Testi.numero(numero)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(width: lato, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct Albero: View {
    let pacchetto: Pacchetto
    @State private var radici: [Nodo] = []

    var body: some View {
        GeometryReader { g in
            let lato = (g.size.width - 16 * 3) / 2
            ScrollView {
                LazyVGrid(columns: [GridItem(.fixed(lato), spacing: 16), GridItem(.fixed(lato), spacing: 16)],
                          alignment: .leading, spacing: 18) {
                    ForEach(radici) { nodo in
                        NavigationLink(value: nodo) {
                            Scheda(pacchetto: pacchetto, nodo: nodo, lato: lato, numero: nodo.quantiColRamo)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                if radici.isEmpty {
                    Text("In questo pacchetto non ci sono nodi con delle foto.")
                        .foregroundStyle(.secondary).padding()
                }
            }
        }
        .navigationTitle("Nodi")
        .onAppear { if radici.isEmpty { radici = (try? pacchetto.archivio.nodi(figliDi: nil)) ?? [] } }
    }
}

struct NodoVista: View {
    let pacchetto: Pacchetto
    let nodo: Nodo
    @State private var figli: [Nodo] = []
    @State private var soloQui = false
    @State private var vecchiePrima = false

    var body: some View {
        let filtro = Filtro(nodo: nodo.id, soloQui: soloQui, vecchiePrima: vecchiePrima)
        GrigliaGiorni(pacchetto: pacchetto, filtro: filtro, testa: AnyView(testa),
                      vuota: soloQui ? "Nessuna foto attaccata proprio qui: sono tutte nei rami sotto." : "Qui non ci sono foto.")
            .id(filtro)
            .navigationTitle(nodo.nome)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Menu {
                    Toggle("Solo qui", isOn: $soloQui)
                    Picker("Ordina", selection: $vecchiePrima) {
                        Text("Più recenti prima").tag(false)
                        Text("Più vecchie prima").tag(true)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .onAppear { if figli.isEmpty { figli = (try? pacchetto.archivio.nodi(figliDi: nodo.id)) ?? [] } }
    }

    private var testa: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !figli.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(figli) { f in
                            NavigationLink(value: f) {
                                Scheda(pacchetto: pacchetto, nodo: f, lato: 96, numero: soloQui ? f.quanti : f.quantiColRamo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
            }
            Text(soloQui ? "Solo qui: \(Testi.foto(nodo.quanti))"
                         : "\(Testi.foto(nodo.quantiColRamo)), compresi i rami sotto")
                .font(.footnote).foregroundStyle(.secondary)
                .padding(.horizontal, 12)
        }
        .padding(.top, 8)
    }
}
