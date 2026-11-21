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

struct Persone: View {
    let pacchetto: Pacchetto
    let cima: Int
    @State private var tutte: [Persona] = []
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
                        Scheda {
                            ForEach(Array(tutte.enumerated()), id: \.element.id) { i, p in
                                if i > 0 { Separa() }
                                NavigationLink(value: p) {
                                    Riga(titolo: p.nome, sottotitolo: Testi.periodo(p.dal, p.al), numero: p.quanti) {
                                        Volto(pacchetto: pacchetto, persona: p, lato: 44)
                                    }
                                }
                                .buttonStyle(Premibile())
                            }
                        }
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
        .testaCompatta("Persone", visibile: compatta) { AzioniDiTesta() }
        .background(Tinta.fondo.ignoresSafeArea())
        .senzaBarraDiSistema()
        .onAppear { if tutte.isEmpty { tutte = (try? pacchetto.archivio.persone()) ?? [] } }
    }

    private var sottotitolo: String? {
        guard !tutte.isEmpty else { return nil }
        return tutte.count == 1 ? "1 persona" : "\(Testi.numero(tutte.count)) persone"
    }
}

struct PersonaVista: View {
    let pacchetto: Pacchetto
    let persona: Persona
    @State private var compagni: [Compagno] = []

    var body: some View {
        GrigliaGiorni(pacchetto: pacchetto, filtro: Filtro(persone: [persona.id]), titolo: persona.nome,
                      sottotitolo: [Testi.foto(persona.quanti), Testi.periodo(persona.dal, persona.al)]
                        .compactMap { $0 }.joined(separator: " · "),
                      testa: AnyView(testa))
            .onAppear { if compagni.isEmpty { compagni = (try? pacchetto.archivio.insieme(a: persona.id)) ?? [] } }
    }

    @ViewBuilder
    private var testa: some View {
        if !compagni.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("SPESSO INSIEME A").etichettaMaiuscola().padding(.horizontal, 16)
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(compagni) { c in
                            NavigationLink(value: Coppia(prima: persona, seconda: c.persona)) {
                                VStack(spacing: 5) {
                                    Volto(pacchetto: pacchetto, persona: c.persona, lato: 56)
                                    Text(c.persona.nome).font(.system(size: 12)).foregroundStyle(Tinta.ink)
                                        .lineLimit(2).multilineTextAlignment(.center)
                                    Text(Testi.numero(c.quante)).font(.system(size: 11)).foregroundStyle(Tinta.tenue)
                                        .monospacedDigit()
                                }
                                .frame(width: 70)
                            }
                            .buttonStyle(Premuto())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.bottom, 6)
        }
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
