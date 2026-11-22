import SwiftUI
import VisoreKit

struct Volto: View {
    let pacchetto: Pacchetto
    let persona: Persona
    let lato: CGFloat
    @State private var immagine: UIImage?
    @Environment(\.displayScale) private var scala

    var body: some View {
        ZStack {
            Circle().fill(Tinta.alone)
            if let immagine {
                Image(uiImage: immagine).resizable().scaledToFill()
            } else {
                Text(String(persona.nome.prefix(1)).uppercased())
                    .font(Carattere.serif(lato * 0.44, .body))
                    .foregroundStyle(Tinta.accento)
            }
        }
        .frame(width: lato, height: lato)
        .clipShape(Circle())
        .task(id: persona.id) {
            guard let posto = persona.volto else { return }
            immagine = Miniature.tutte.pronta(posto)
            if immagine == nil { immagine = await Miniature.tutte.carica(pacchetto, posto, lato: lato * scala) }
        }
    }
}

struct GruppoLettera: Identifiable {
    var id: String { lettera }
    let lettera: String
    let persone: [Persona]
}

struct PiuPresenti: View {
    let pacchetto: Pacchetto
    let primi: [Persona]
    @State private var pieni = false

    var body: some View {
        let massimo = max(1, primi.map(\.quanti).max() ?? 1)
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(primi.enumerated()), id: \.element.id) { i, p in
                NavigationLink(value: p) {
                    VStack(spacing: 5) {
                        TondoConAnello(pacchetto: pacchetto, persona: p,
                                       quota: Double(p.quanti) / Double(massimo), pieno: pieni)
                        Text(p.nome).font(.system(size: 12.5)).foregroundStyle(Tinta.ink).lineLimit(1)
                        Text(Testi.numero(p.quanti)).font(.system(size: 11)).foregroundStyle(Tinta.tenue)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremutoVivo())
                .entra(i)
            }
            ForEach(primi.count..<4, id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }
        }
        .onAppear {
            guard !pieni else { return }
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.9).delay(0.2)) { pieni = true }
        }
    }
}

struct Persone: View {
    let pacchetto: Pacchetto
    let cima: Int
    @State private var tutte: [Persona] = []
    @State private var gruppi: [GruppoLettera] = []
    @State private var compatta = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Testa(titolo: "Persone", sottotitolo: sottotitolo) { AzioniDiTesta() }
                        .id("cima")
                    if tutte.isEmpty {
                        Vuoto(titolo: "Nessuna persona", testo: "In questo pacchetto non ci sono persone con un nome.",
                              simbolo: "person.2")
                    } else {
                        Titoletto(testo: "LE PIÙ PRESENTI")
                            .padding(.horizontal, 16)
                        PiuPresenti(pacchetto: pacchetto, primi: primi)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                        Titoletto(testo: "TUTTE, DALLA A ALLA Z")
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                        ForEach(gruppi) { g in
                            Text(g.lettera)
                                .font(Carattere.piccolo)
                                .foregroundStyle(Tinta.tenue)
                                .padding(.horizontal, 20)
                                .padding(.top, 14)
                                .padding(.bottom, 6)
                                .id("lettera-" + g.lettera)
                            Scheda {
                                ForEach(Array(g.persone.enumerated()), id: \.element.id) { i, p in
                                    if i > 0 { Separa() }
                                    NavigationLink(value: p) {
                                        Riga(titolo: p.nome, sottotitolo: Testi.periodo(p.dal, p.al), numero: p.quanti) {
                                            VoltoVivo(pacchetto: pacchetto, persona: p, lato: 40)
                                        }
                                    }
                                    .buttonStyle(PremibileVivo())
                                }
                            }
                            .padding(.leading, 16)
                            .padding(.trailing, gruppi.count > 1 ? 34 : 16)
                            .entra(0)
                        }
                    }
                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .segueLaTesta($compatta)
            .overlay(alignment: .trailing) {
                if gruppi.count > 1 {
                    IndiceLettere(lettere: gruppi.map(\.lettera)) { l in
                        proxy.scrollTo("lettera-" + l, anchor: UnitPoint(x: 0.5, y: 0.1))
                    }
                    .padding(.trailing, 2)
                }
            }
            .onChange(of: cima) { _, _ in withAnimation(Moto.scena) { proxy.scrollTo("cima", anchor: .top) } }
        }
        .testaCompatta("Persone", visibile: compatta) { AzioniDiTesta() }
        .background(Tinta.fondo.ignoresSafeArea())
        .senzaBarraDiSistema()
        .onAppear { if tutte.isEmpty { carica() } }
    }

    private var primi: [Persona] {
        Array(tutte.sorted { $0.quanti == $1.quanti ? $0.id < $1.id : $0.quanti > $1.quanti }.prefix(4))
    }

    private func carica() {
        tutte = (try? pacchetto.archivio.personePerNome()) ?? []
        let perLettera = Dictionary(grouping: tutte, by: Self.iniziale)
        gruppi = perLettera.keys
            .sorted { a, b in a == "#" ? false : (b == "#" ? true : a < b) }
            .map { GruppoLettera(lettera: $0, persone: perLettera[$0] ?? []) }
    }

    private static func iniziale(_ p: Persona) -> String {
        let piano = p.nome.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                   locale: Locale(identifier: "it_IT"))
        guard let c = piano.first, c.isLetter, c.isASCII else { return "#" }
        return String(c).uppercased()
    }

    private var sottotitolo: String? {
        guard !tutte.isEmpty else { return nil }
        return tutte.count == 1 ? "1 persona con un nome" : "\(Testi.numero(tutte.count)) persone con un nome"
    }
}

struct PersonaVista: View {
    let pacchetto: Pacchetto
    let persona: Persona
    @State private var riassunto: Riassunto?
    @State private var anno: String?
    @State private var luogo: Int64?

    var body: some View {
        let filtro = Filtro(persone: [persona.id], luogo: luogo, anno: anno)
        GrigliaGiorni(pacchetto: pacchetto, filtro: filtro, titolo: persona.nome,
                      sottotitolo: [Testi.foto(persona.quanti), Testi.periodo(persona.dal, persona.al)]
                        .compactMap { $0 }.joined(separator: " · "),
                      testa: AnyView(testa),
                      vuota: anno != nil || luogo != nil ? "Nessuna foto con questi filtri: togline uno." : "Qui non ci sono foto.")
            .id(filtro)
            .onAppear {
                if riassunto == nil { riassunto = try? pacchetto.archivio.riassunto(filtro: Filtro(persone: [persona.id])) }
            }
    }

    private func numeri(_ r: Riassunto) -> [(String, String)] {
        let piu = r.anni.max { $0.quanti == $1.quanti ? $0.anno > $1.anno : $0.quanti < $1.quanti }
        return [(r.dal.map { String($0.prefix(4)) } ?? "—", "la prima foto"),
                (piu?.anno ?? "—", "l'anno con più"),
                (r.al.map { String($0.prefix(4)) } ?? "—", "l'ultima")]
    }

    private var testa: some View {
        VStack(alignment: .leading, spacing: 10) {
            EroePersona(pacchetto: pacchetto, persona: persona)
            if let r = riassunto {
                Numeri(voci: numeri(r)).entra(1)
                if !r.persone.isEmpty {
                    Titoletto(testo: "SPESSO INSIEME A", nota: "tocca per aprire")
                    FilaVolti(pacchetto: pacchetto, compagni: r.persone)
                }
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
                if !r.nodi.isEmpty {
                    Titoletto(testo: "NEI NODI")
                    Scheda {
                        ForEach(Array(r.nodi.enumerated()), id: \.element.id) { i, n in
                            if i > 0 { Separa(rientro: 90) }
                            NavigationLink(value: n.nodo) {
                                RigaNodo(pacchetto: pacchetto, nodo: n.nodo, numero: n.quante)
                            }
                            .buttonStyle(PremibileVivo())
                            .entra(i)
                        }
                    }
                }
                if !r.persone.isEmpty {
                    Titoletto(testo: "INSIEME, IN DUE")
                    Scheda {
                        ForEach(Array(r.persone.prefix(3).enumerated()), id: \.element.id) { i, c in
                            if i > 0 { Separa() }
                            NavigationLink(value: Coppia(prima: persona, seconda: c.persona)) {
                                Riga(titolo: "\(persona.nome) e \(c.persona.nome)", numero: c.quante) {
                                    DueVolti(pacchetto: pacchetto, prima: persona, seconda: c.persona)
                                }
                            }
                            .buttonStyle(PremibileVivo())
                            .entra(i)
                        }
                    }
                }
                FiltriAttivi(anno: $anno, luogo: $luogo, luoghi: r.luoghi)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 720, alignment: .leading)
    }
}

struct Coppia: Hashable {
    let prima: Persona
    let seconda: Persona
}

struct CoppiaVista: View {
    let pacchetto: Pacchetto
    let coppia: Coppia
    @State private var quante: Int?

    var body: some View {
        let filtro = Filtro(persone: [coppia.prima.id, coppia.seconda.id])
        GrigliaGiorni(pacchetto: pacchetto, filtro: filtro, titolo: "\(coppia.prima.nome) e \(coppia.seconda.nome)",
                      sottotitolo: quante.map { Testi.foto($0) + " insieme" }, testa: AnyView(testa),
                      vuota: "Nessuna foto con tutte e due.")
            .onAppear { if quante == nil { quante = try? pacchetto.archivio.quanti(filtro: filtro) } }
    }

    private var testa: some View {
        HStack(spacing: 0) {
            Volto(pacchetto: pacchetto, persona: coppia.prima, lato: 52)
            Volto(pacchetto: pacchetto, persona: coppia.seconda, lato: 52)
                .overlay(Circle().stroke(Tinta.fondo, lineWidth: 3))
                .padding(.leading, -16)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
