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
            Circle().fill(Color(white: 0.16))
            if let immagine {
                Image(uiImage: immagine).resizable().scaledToFill()
            } else {
                Text(String(persona.nome.prefix(1)).uppercased())
                    .font(.system(size: lato * 0.42, weight: .semibold))
                    .foregroundStyle(.secondary)
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
    @State private var tutte: [Persona] = []

    var body: some View {
        GeometryReader { g in
            let lato = min(120, (g.size.width - 16 * 4) / 3)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 20) {
                    ForEach(tutte) { p in
                        NavigationLink(value: p) {
                            VStack(spacing: 4) {
                                Volto(pacchetto: pacchetto, persona: p, lato: lato)
                                Text(p.nome).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text(Testi.numero(p.quanti)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                if tutte.isEmpty {
                    Text("In questo pacchetto non ci sono persone con un nome.")
                        .foregroundStyle(.secondary).padding()
                }
            }
        }
        .navigationTitle("Persone")
        .onAppear { if tutte.isEmpty { tutte = (try? pacchetto.archivio.persone()) ?? [] } }
    }
}

struct PersonaVista: View {
    let pacchetto: Pacchetto
    let persona: Persona
    @State private var compagni: [Compagno] = []

    var body: some View {
        GrigliaGiorni(pacchetto: pacchetto, filtro: Filtro(persone: [persona.id]), testa: AnyView(testa))
            .navigationTitle(persona.nome)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if compagni.isEmpty { compagni = (try? pacchetto.archivio.insieme(a: persona.id)) ?? [] } }
    }

    private var testa: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Volto(pacchetto: pacchetto, persona: persona, lato: 72)
                VStack(alignment: .leading, spacing: 3) {
                    Text(persona.nome).font(.title2.bold()).lineLimit(2)
                    Text([Testi.foto(persona.quanti), Testi.periodo(persona.dal, persona.al)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if !compagni.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spesso insieme a").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 14) {
                            ForEach(compagni) { c in
                                NavigationLink(value: Coppia(prima: persona, seconda: c.persona)) {
                                    VStack(spacing: 3) {
                                        Volto(pacchetto: pacchetto, persona: c.persona, lato: 52)
                                        Text(c.persona.nome).font(.caption).lineLimit(1)
                                    }
                                    .frame(width: 64)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}

struct Coppia: Hashable {
    let prima: Persona
    let seconda: Persona
}

struct CoppiaVista: View {
    let pacchetto: Pacchetto
    let coppia: Coppia
    @Environment(\.dismiss) private var indietro
    @State private var quante: Int?

    var body: some View {
        let filtro = Filtro(persone: [coppia.prima.id, coppia.seconda.id])
        GrigliaGiorni(pacchetto: pacchetto, filtro: filtro, testa: AnyView(testa),
                      vuota: "Nessuna foto con tutte e due.")
            .navigationTitle("Tutte e due")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if quante == nil { quante = try? pacchetto.archivio.quanti(filtro: filtro) } }
    }

    private var testa: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                Volto(pacchetto: pacchetto, persona: coppia.prima, lato: 48)
                Volto(pacchetto: pacchetto, persona: coppia.seconda, lato: 48)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .offset(x: 30)
            }
            .frame(width: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(coppia.prima.nome) e \(coppia.seconda.nome)").font(.headline).lineLimit(2)
                if let quante { Text(Testi.foto(quante)).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            Button { indietro() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }
            .accessibilityLabel("Togli «tutte e due»")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
