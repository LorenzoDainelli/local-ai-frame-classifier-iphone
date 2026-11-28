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
    @State private var periodo: String?

    var body: some View {
        Riga(titolo: nodo.nome, sottotitolo: sotto, numero: numero ?? nodo.quantiColRamo) {
            Mosaico(pacchetto: pacchetto, filtro: Filtro(nodo: nodo.id))
        }
        .task(id: nodo.id) {
            guard figli == nil else { return }
            figli = (try? pacchetto.archivio.nodi(figliDi: nodo.id))?.count ?? 0
            let anni = (try? pacchetto.archivio.anni(filtro: Filtro(nodo: nodo.id))) ?? []
            periodo = Testi.periodo(anni.last?.anno, anni.first?.anno)
        }
    }

    private var sotto: String? {
        var pezzi: [String] = []
        if let figli, figli > 0 {
            pezzi.append(figli == 1 ? "1 sottocategoria" : "\(Testi.numero(figli)) sottocategorie")
        }
        if let periodo { pezzi.append(periodo) }
        return pezzi.isEmpty ? nil : pezzi.joined(separator: " · ")
    }
}

struct ElencoNodi: View {
    let pacchetto: Pacchetto
    let nodi: [Nodo]
    var soloQui = false

    var body: some View {
        Scheda {
            ForEach(Array(nodi.enumerated()), id: \.element.id) { i, nodo in
                if i > 0 { Separa(rientro: 90) }
                Collegamento(nodo) {
                    RigaNodo(pacchetto: pacchetto, nodo: nodo, numero: soloQui ? nodo.quanti : nodo.quantiColRamo)
                }
                .buttonStyle(PremibileVivo())
                .accessibilityIdentifier("nodo")
                .entra(i)
            }
        }
    }
}

struct Albero: View {
    let pacchetto: Pacchetto
    let cima: Int
    @State private var radici: [Nodo] = []
    @State private var preferiti: [Nodo] = []
    @State private var compatta = false
    @AppStorage private var colCuore: String

    init(pacchetto: Pacchetto, cima: Int) {
        self.pacchetto = pacchetto
        self.cima = cima
        self._colCuore = AppStorage(wrappedValue: "", NodiColCuore.chiave(archivio: pacchetto.carta.archivio))
    }

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
                        VStack(alignment: .leading, spacing: 10) {
                            if !preferiti.isEmpty {
                                Titoletto(testo: "COL CUORE")
                                ElencoNodi(pacchetto: pacchetto, nodi: preferiti)
                                    .accessibilityIdentifier("nodi-col-cuore")
                                Titoletto(testo: "TUTTI")
                            }
                            ElencoNodi(pacchetto: pacchetto, nodi: radici)
                        }
                        .padding(.horizontal, 16)
                        .animation(Moto.passo, value: preferiti.map(\.id))
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
        .onAppear {
            if radici.isEmpty { radici = (try? pacchetto.archivio.nodi(figliDi: nil)) ?? [] }
            leggiPreferiti()
        }
        .onChange(of: colCuore) { _, _ in leggiPreferiti() }
    }

    private func leggiPreferiti() {
        preferiti = (try? pacchetto.archivio.nodi(con: NodiColCuore.leggi(colCuore))) ?? []
    }

    private var sottotitolo: String? {
        guard !radici.isEmpty else { return nil }
        return radici.count == 1 ? "1 categoria" : "\(Testi.numero(radici.count)) categorie"
    }
}

enum OrdineFigli: Hashable {
    case fisso, foto, nome
}

struct NodoVista: View {
    let pacchetto: Pacchetto
    let nodo: Nodo
    @State private var figli: [Nodo] = []
    @State private var soloQui = false
    @State private var vecchiePrima = false
    @State private var tutti = false
    @State private var ordine = OrdineFigli.fisso
    @State private var anno: String?
    @State private var luogo: Int64?
    @State private var riassunto: Riassunto?
    @State private var copertine: [Scatto] = []
    @AppStorage private var colCuore: String

    init(pacchetto: Pacchetto, nodo: Nodo) {
        self.pacchetto = pacchetto
        self.nodo = nodo
        self._colCuore = AppStorage(wrappedValue: "", NodiColCuore.chiave(archivio: pacchetto.carta.archivio))
    }

    var body: some View {
        let filtro = Filtro(nodo: nodo.id, soloQui: soloQui, luogo: luogo, anno: anno, vecchiePrima: vecchiePrima)
        GrigliaGiorni(pacchetto: pacchetto, filtro: filtro, titolo: nodo.nome,
                      sottotitolo: soloQui ? "Solo qui: \(Testi.foto(nodo.quanti))"
                                           : "\(Testi.foto(nodo.quantiColRamo)), compresi i rami sotto",
                      testa: AnyView(testa), menu: AnyView(HStack(spacing: 8) { cuore; menu }), vuota: vuota)
            .id(filtro)
            .onAppear { carica() }
            .onChange(of: soloQui) { _, _ in
                riassunto = nil
                carica()
            }
    }

    private var vuota: String {
        if anno != nil || luogo != nil { return "Nessuna foto con questi filtri: togline uno." }
        return soloQui ? "Nessuna foto attaccata proprio qui: sono tutte nei rami sotto." : "Qui non ci sono foto."
    }

    private func carica() {
        if figli.isEmpty { figli = (try? pacchetto.archivio.nodi(figliDi: nodo.id)) ?? [] }
        if copertine.isEmpty {
            copertine = (try? pacchetto.archivio.copertine(filtro: Filtro(nodo: nodo.id), quante: 3)) ?? []
        }
        if riassunto == nil {
            riassunto = try? pacchetto.archivio.riassunto(filtro: Filtro(nodo: nodo.id, soloQui: soloQui),
                                                          figliDi: nodo.id)
        }
    }

    private var ordinati: [Nodo] {
        switch ordine {
        case .fisso: return figli
        case .foto: return figli.sorted { $0.quantiColRamo > $1.quantiColRamo }
        case .nome: return figli.sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending }
        }
    }

    private var cuore: some View {
        let acceso = NodiColCuore.ha(colCuore, nodo.id)
        return Button {
            withAnimation(Moto.molla) { colCuore = NodiColCuore.cambia(colCuore, nodo.id) }
        } label: {
            Image(systemName: acceso ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(acceso ? Tinta.accento : Tinta.attenuato)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 38, height: 38)
                .vetro(Circle(), interattivo: true)
                .contentShape(Circle())
        }
        .buttonStyle(Premuto(quanto: 0.9))
        .sensoryFeedback(.impact(weight: .light), trigger: acceso)
        .accessibilityLabel(acceso ? "Togli dai nodi col cuore" : "Metti tra i nodi col cuore")
        .accessibilityIdentifier("cuore-nodo")
    }

    private var menu: some View {
        Menu {
            Toggle("Solo qui", isOn: $soloQui)
            if figli.count > 1 {
                Section("Ordine delle sottocategorie") {
                    Picker("Ordine delle sottocategorie", selection: $ordine.animation(Moto.scena)) {
                        Text("Come sul fisso").tag(OrdineFigli.fisso)
                        Text("Più foto").tag(OrdineFigli.foto)
                        Text("Nome").tag(OrdineFigli.nome)
                    }
                    .pickerStyle(.inline)
                }
            }
            Section("Ordine delle foto") {
                Picker("Ordine delle foto", selection: $vecchiePrima) {
                    Text("Più recenti prima").tag(false)
                    Text("Più vecchie prima").tag(true)
                }
                .pickerStyle(.inline)
            }
        } label: {
            FacciaTondo(simbolo: "ellipsis")
        }
        .accessibilityLabel("Opzioni")
    }

    private var numeri: [(String, String)] {
        [(Testi.numero(nodo.quantiColRamo), "scatti nel ramo"),
         (Testi.numero(nodo.quanti), "solo qui"),
         (Testi.periodo(riassunto?.dal, riassunto?.al) ?? "—", "periodo")]
    }

    private var testa: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !copertine.isEmpty {
                EroeNodo(pacchetto: pacchetto, scatti: copertine).entra(0)
            }
            Numeri(voci: numeri).entra(1)
            if !figli.isEmpty {
                let tutte = ordinati
                let mostrati = tutti || tutte.count <= 5 ? tutte : Array(tutte.prefix(4))
                Titoletto(testo: figli.count == 1 ? "1 SOTTOCATEGORIA"
                                                  : "\(Testi.numero(figli.count)) SOTTOCATEGORIE")
                ElencoNodi(pacchetto: pacchetto, nodi: mostrati, soloQui: soloQui)
                if mostrati.count < tutte.count {
                    Button {
                        withAnimation(Moto.passo) { tutti = true }
                    } label: {
                        Text("Mostra tutte (\(Testi.numero(tutte.count)))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tinta.accento)
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(Premuto())
                }
            }
            if let r = riassunto {
                if r.anni.count > 1 {
                    Titoletto(testo: "NEGLI ANNI")
                    AnniABarre(anni: Array(r.anni.reversed()), scelto: anno) { a in
                        withAnimation(Moto.passo) { anno = anno == a ? nil : a }
                    }
                }
                if !r.luoghi.isEmpty {
                    Titoletto(testo: "DOVE")
                    PilloleLuoghi(luoghi: r.luoghi, scelto: luogo) { l in
                        withAnimation(Moto.passo) { luogo = luogo == l ? nil : l }
                    }
                }
                if !r.persone.isEmpty {
                    Titoletto(testo: "PERSONE", nota: "tocca per aprire")
                    FilaVolti(pacchetto: pacchetto, compagni: r.persone)
                }
                FiltriAttivi(anno: $anno, luogo: $luogo, luoghi: r.luoghi)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 720, alignment: .leading)
    }
}
