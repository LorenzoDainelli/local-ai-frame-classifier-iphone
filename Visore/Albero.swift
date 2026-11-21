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
        .clipShape(RoundedRectangle(cornerRadius: lato > 60 ? 10 : 8, style: .continuous))
        .task(id: nodo.id) {
            guard let s = try? pacchetto.archivio.copertina(nodo: nodo.id) else { return }
            let posto = s.mini ?? s.posto
            immagine = Miniature.tutte.pronta(posto)
            if immagine == nil { immagine = await Miniature.tutte.carica(pacchetto, posto, lato: lato * scala) }
        }
    }
}

struct RigaNodo: View {
    let pacchetto: Pacchetto
    let nodo: Nodo
    var numero: Int? = nil
    @State private var figli: Int?

    var body: some View {
        Riga(titolo: nodo.nome, sottotitolo: sotto, numero: numero ?? nodo.quantiColRamo) {
            Copertina(pacchetto: pacchetto, nodo: nodo, lato: 44)
        }
        .task(id: nodo.id) {
            if figli == nil { figli = (try? pacchetto.archivio.nodi(figliDi: nodo.id))?.count ?? 0 }
        }
    }

    private var sotto: String? {
        guard let figli, figli > 0 else { return nil }
        return figli == 1 ? "1 sottocategoria" : "\(Testi.numero(figli)) sottocategorie"
    }
}

struct ElencoNodi: View {
    let pacchetto: Pacchetto
    let nodi: [Nodo]
    var soloQui = false

    var body: some View {
        Scheda {
            ForEach(Array(nodi.enumerated()), id: \.element.id) { i, nodo in
                if i > 0 { Separa() }
                NavigationLink(value: nodo) {
                    RigaNodo(pacchetto: pacchetto, nodo: nodo, numero: soloQui ? nodo.quanti : nodo.quantiColRamo)
                }
                .buttonStyle(Premibile())
            }
        }
    }
}

struct Albero: View {
    let pacchetto: Pacchetto
    let cima: Int
    @State private var radici: [Nodo] = []
    @State private var compatta = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Testa(titolo: "Nodi", sottotitolo: sottotitolo) { AzioniDiTesta() }
                        .id("cima")
                    if radici.isEmpty {
                        Vuoto(titolo: "Nessun nodo", testo: "In questo pacchetto non ci sono nodi con delle foto.",
                              simbolo: "square.grid.2x2")
                    } else {
                        ElencoNodi(pacchetto: pacchetto, nodi: radici)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .segueLaTesta($compatta)
            .onChange(of: cima) { _, _ in withAnimation(Moto.scena) { proxy.scrollTo("cima", anchor: .top) } }
        }
        .testaCompatta("Nodi", visibile: compatta) { AzioniDiTesta() }
        .background(Tinta.fondo.ignoresSafeArea())
        .senzaBarraDiSistema()
        .onAppear { if radici.isEmpty { radici = (try? pacchetto.archivio.nodi(figliDi: nil)) ?? [] } }
    }

    private var sottotitolo: String? {
        guard !radici.isEmpty else { return nil }
        return radici.count == 1 ? "1 categoria" : "\(Testi.numero(radici.count)) categorie"
    }
}

struct NodoVista: View {
    let pacchetto: Pacchetto
    let nodo: Nodo
    @State private var figli: [Nodo] = []
    @State private var soloQui = false
    @State private var vecchiePrima = false
    @State private var tutti = false

    var body: some View {
        let filtro = Filtro(nodo: nodo.id, soloQui: soloQui, vecchiePrima: vecchiePrima)
        GrigliaGiorni(pacchetto: pacchetto, filtro: filtro, titolo: nodo.nome,
                      sottotitolo: soloQui ? "Solo qui: \(Testi.foto(nodo.quanti))"
                                           : "\(Testi.foto(nodo.quantiColRamo)), compresi i rami sotto",
                      testa: AnyView(testa), menu: AnyView(menu),
                      vuota: soloQui ? "Nessuna foto attaccata proprio qui: sono tutte nei rami sotto." : "Qui non ci sono foto.")
            .id(filtro)
            .onAppear { if figli.isEmpty { figli = (try? pacchetto.archivio.nodi(figliDi: nodo.id)) ?? [] } }
    }

    private var menu: some View {
        Menu {
            Toggle("Solo qui", isOn: $soloQui)
            Picker("Ordina", selection: $vecchiePrima) {
                Text("Più recenti prima").tag(false)
                Text("Più vecchie prima").tag(true)
            }
        } label: {
            FacciaTondo(simbolo: "ellipsis")
        }
        .accessibilityLabel("Opzioni")
    }

    @ViewBuilder
    private var testa: some View {
        if !figli.isEmpty {
            let mostrati = tutti || figli.count <= 5 ? figli : Array(figli.prefix(4))
            VStack(alignment: .leading, spacing: 8) {
                Text(figli.count == 1 ? "1 SOTTOCATEGORIA" : "\(Testi.numero(figli.count)) SOTTOCATEGORIE")
                    .etichettaMaiuscola()
                    .padding(.horizontal, 4)
                ElencoNodi(pacchetto: pacchetto, nodi: mostrati, soloQui: soloQui)
                if mostrati.count < figli.count {
                    Button {
                        withAnimation(Moto.passo) { tutti = true }
                    } label: {
                        Text("Mostra tutte (\(Testi.numero(figli.count)))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tinta.accento)
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(Premuto())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }
}
