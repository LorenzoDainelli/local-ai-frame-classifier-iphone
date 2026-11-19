import SwiftUI
import VisoreKit

enum Recenti {
    static let chiave = "visore.recenti"
    static let quante = 10

    static func tutte() -> [String] { UserDefaults.standard.stringArray(forKey: chiave) ?? [] }

    static func aggiungi(_ testo: String) {
        let pulito = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pulito.isEmpty else { return }
        var elenco = tutte().filter { $0.caseInsensitiveCompare(pulito) != .orderedSame }
        elenco.insert(pulito, at: 0)
        UserDefaults.standard.set(Array(elenco.prefix(quante)), forKey: chiave)
    }

    static func togli(_ testo: String) {
        UserDefaults.standard.set(tutte().filter { $0 != testo }, forKey: chiave)
    }

    static func dimentica() { UserDefaults.standard.removeObject(forKey: chiave) }
}

enum Frase {
    static func elenco(_ pezzi: [String]) -> String {
        guard pezzi.count > 1 else { return pezzi.first ?? "" }
        return pezzi.dropLast().joined(separator: ", ") + " e " + pezzi.last!
    }

    static func cerco(_ parole: [String], conParole: Bool) -> String? {
        guard !parole.isEmpty else { return nil }
        var dove: [String] = []
        if conParole { dove.append("fra le parole preparate dal PC") }
        dove.append("nei nomi dei nodi")
        dove.append("nelle note")
        if parole.contains(where: { $0.count == 4 && $0.allSatisfy { $0.isASCII && $0.isNumber } }) {
            dove.append("nelle date")
        }
        return "cerco \(parole.joined(separator: " e ")) " + elenco(dove)
    }

    struct Genere: Identifiable {
        let id: String
        let nome: String
    }

    static let generi = [Genere(id: "foto", nome: "Foto"), Genere(id: "live", nome: "Live photo"),
                         Genere(id: "video", nome: "Video")]

    static func genere(_ g: String) -> String { generi.first { $0.id == g }?.nome ?? g }
}

struct Pillola: View {
    let testo: String
    let togli: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(testo).lineLimit(1)
            Button(action: togli) { Image(systemName: "xmark").font(.caption2.weight(.bold)) }
                .accessibilityLabel("Togli \(testo)")
        }
        .font(.subheadline)
        .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 7)
        .background(Color(white: 0.18), in: Capsule())
    }
}

struct Cerca: View {
    let pacchetto: Pacchetto
    @State private var testo = ""
    @State private var cercato = ""
    @State private var filtro = Filtro()
    @State private var recenti = Recenti.tutte()
    @State private var anni: [Anno] = []
    @State private var luoghi: [Luogo] = []
    @State private var persone: [Persona] = []
    @State private var scelta: Scelta?
    @State private var conParole = false

    enum Scelta: String, Identifiable {
        case luogo, persona, nodo
        var id: String { rawValue }
    }

    private var completo: Filtro {
        var f = filtro
        f.parole = Filtro.parole(di: cercato)
        return f
    }

    var body: some View {
        let f = completo
        Group {
            if f.vuoto {
                inizio
            } else {
                GrigliaGiorni(pacchetto: pacchetto, filtro: f, testa: AnyView(testa(f)), vuota: nienteDa(f))
                    .id(f)
            }
        }
        .navigationTitle("Cerca")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $testo, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Nodi, note, persone, luoghi, anni")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .onSubmit(of: .search) { ricorda() }
        .task(id: testo) {
            try? await Task.sleep(for: .milliseconds(250))
            if !Task.isCancelled { cercato = testo }
        }
        .toolbar { aggiungi }
        .sheet(item: $scelta) { s in
            NavigationStack { foglio(s) }
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            if anni.isEmpty {
                anni = (try? pacchetto.archivio.anni()) ?? []
                luoghi = (try? pacchetto.archivio.luoghi()) ?? []
                persone = (try? pacchetto.archivio.persone()) ?? []
                conParole = pacchetto.archivio.ciSonoParole()
            }
        }
    }

    private var inizio: some View {
        List {
            if !recenti.isEmpty {
                Section {
                    ForEach(recenti, id: \.self) { r in
                        Button {
                            testo = r
                            cercato = r
                        } label: {
                            Label(r, systemImage: "clock.arrow.circlepath").foregroundStyle(.primary)
                        }
                    }
                    .onDelete { righe in
                        for i in righe { Recenti.togli(recenti[i]) }
                        recenti = Recenti.tutte()
                    }
                } header: {
                    HStack {
                        Text("Ricerche recenti")
                        Spacer()
                        Button("Cancella") {
                            Recenti.dimentica()
                            recenti = []
                        }
                        .font(.footnote)
                    }
                }
            }
            Section {
                Text("Scrivi una parola, oppure aggiungi un filtro con il tasto in alto a destra: periodo, luogo, persona, nodo, tipo. I filtri si sommano.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func testa(_ f: Filtro) -> some View {
        let trovati = try? pacchetto.archivio.trovati(cercato)
        return VStack(alignment: .leading, spacing: 10) {
            if let frase = Frase.cerco(f.parole, conParole: conParole) {
                Text(frase).font(.footnote).foregroundStyle(.secondary)
            }
            if !filtro.vuoto {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(pillole) { p in Pillola(testo: p.testo, togli: p.togli) }
                        Button("Togli tutto") { withAnimation { filtro = Filtro() } }.font(.subheadline)
                    }
                }
                .scrollIndicators(.hidden)
            }
            if let trovati, !trovati.vuoto {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(trovati.persone) { p in
                        NavigationLink(value: p) {
                            Riga(icona: "person.crop.circle", testo: "\(p.nome) · \(Testi.foto(p.quanti))")
                        }
                    }
                    ForEach(trovati.nodi) { n in
                        NavigationLink(value: n) {
                            Riga(icona: "square.stack", testo: "\(n.nome) · \(Testi.foto(n.quantiColRamo))")
                        }
                    }
                    ForEach(trovati.luoghi) { l in
                        Button { usa { $0.luogo = l.id } } label: {
                            Riga(icona: "mappin.and.ellipse", testo: "\(l.nome) · \(Testi.foto(l.quanti))")
                        }
                    }
                    ForEach(trovati.anni) { a in
                        Button { usa { $0.anno = a.anno } } label: {
                            Riga(icona: "calendar", testo: "\(a.anno) · \(Testi.foto(a.quanti))")
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private struct Riga: View {
        let icona: String
        let testo: String

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icona).foregroundStyle(.secondary).frame(width: 22)
                Text(testo).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
    }

    struct Pill: Identifiable {
        let id: String
        let testo: String
        let togli: () -> Void
    }

    private var pillole: [Pill] {
        var uscita: [Pill] = []
        for id in filtro.persone {
            let nome = persone.first { $0.id == id }?.nome ?? (try? pacchetto.archivio.persona(id))?.nome ?? "?"
            uscita.append(Pill(id: "persona-\(id)", testo: nome, togli: { withAnimation { filtro.persone.removeAll { $0 == id } } }))
        }
        if let n = filtro.nodo {
            let nome = (try? pacchetto.archivio.nodo(n))?.nome ?? "?"
            uscita.append(Pill(id: "nodo", testo: filtro.soloQui ? "\(nome) (solo qui)" : nome,
                               togli: { withAnimation { filtro.nodo = nil; filtro.soloQui = false } }))
        }
        if let l = filtro.luogo {
            uscita.append(Pill(id: "luogo", testo: luoghi.first { $0.id == l }?.nome ?? "?",
                               togli: { withAnimation { filtro.luogo = nil } }))
        }
        if let a = filtro.anno { uscita.append(Pill(id: "anno", testo: a, togli: { withAnimation { filtro.anno = nil } })) }
        if let g = filtro.genere {
            uscita.append(Pill(id: "genere", testo: Frase.genere(g), togli: { withAnimation { filtro.genere = nil } }))
        }
        return uscita
    }

    private func nienteDa(_ f: Filtro) -> String {
        var pezzi: [String] = []
        if !f.parole.isEmpty { pezzi.append("«\(f.parole.joined(separator: " "))»") }
        let quanti = pillole.count
        if quanti > 0 { pezzi.append(quanti == 1 ? "il filtro" : "i \(quanti) filtri insieme") }
        let chiesto = Frase.elenco(pezzi)
        let come = quanti > 0 ? "Togli un filtro con la sua × o tocca «Togli tutto»." : "Prova un'altra parola."
        return "Nessuna foto per \(chiesto). \(come)"
    }

    private func usa(_ cambia: (inout Filtro) -> Void) {
        ricorda()
        scelta = nil
        withAnimation {
            cambia(&filtro)
            testo = ""
            cercato = ""
        }
    }

    private func ricorda() {
        Recenti.aggiungi(testo)
        recenti = Recenti.tutte()
    }

    private var aggiungi: some View {
        Menu {
            Menu("Periodo") {
                ForEach(anni) { a in
                    Button("\(a.anno) · \(Testi.numero(a.quanti))") { usa { $0.anno = a.anno } }
                }
            }
            Button("Luogo…") { scelta = .luogo }.disabled(luoghi.isEmpty)
            Button("Persona…") { scelta = .persona }.disabled(persone.isEmpty)
            Button("Nodo…") { scelta = .nodo }
            Menu("Tipo") {
                ForEach(Frase.generi) { g in
                    Button(g.nome) { usa { $0.genere = g.id } }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Aggiungi un filtro")
    }

    @ViewBuilder
    private func foglio(_ s: Scelta) -> some View {
        switch s {
        case .luogo:
            SceltaElenco(titolo: "Luogo", voci: luoghi.map { Voce(id: $0.id, nome: $0.nome, quanti: $0.quanti) }) { id in
                usa { $0.luogo = id }
            }
        case .persona:
            SceltaElenco(titolo: "Persona",
                         voci: persone.filter { !filtro.persone.contains($0.id) }
                             .map { Voce(id: $0.id, nome: $0.nome, quanti: $0.quanti) }) { id in
                usa { $0.persone.append(id) }
            }
        case .nodo:
            SceltaNodo(pacchetto: pacchetto, genitore: nil) { nodo in
                usa {
                    $0.nodo = nodo.id
                    $0.soloQui = false
                }
            }
        }
    }
}

struct Voce: Identifiable {
    let id: Int64
    let nome: String
    let quanti: Int
}

struct SceltaElenco: View {
    let titolo: String
    let voci: [Voce]
    let scegli: (Int64) -> Void
    @State private var cerca = ""
    @Environment(\.dismiss) private var chiudi

    var body: some View {
        let mostrate = cerca.isEmpty ? voci : voci.filter { $0.nome.localizedCaseInsensitiveContains(cerca) }
        List(mostrate) { v in
            Button {
                scegli(v.id)
                chiudi()
            } label: {
                HStack {
                    Text(v.nome).foregroundStyle(.primary)
                    Spacer()
                    Text(Testi.numero(v.quanti)).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .searchable(text: $cerca)
        .navigationTitle(titolo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Annulla") { chiudi() } }
    }
}

struct SceltaNodo: View {
    let pacchetto: Pacchetto
    let genitore: Nodo?
    let scegli: (Nodo) -> Void
    @State private var nodi: [Ramo] = []

    struct Ramo: Identifiable {
        let nodo: Nodo
        let figli: Bool
        var id: Int64 { nodo.id }
    }
    @Environment(\.dismiss) private var chiudi

    var body: some View {
        List {
            if let genitore {
                Button {
                    scegli(genitore)
                } label: {
                    Label("Tutto «\(genitore.nome)»", systemImage: "checkmark.circle")
                }
            }
            ForEach(nodi) { voce in
                let nodo = voce.nodo
                if voce.figli {
                    NavigationLink {
                        SceltaNodo(pacchetto: pacchetto, genitore: nodo, scegli: scegli)
                    } label: {
                        voceNodo(nodo)
                    }
                } else {
                    Button {
                        scegli(nodo)
                    } label: {
                        voceNodo(nodo).foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle(genitore?.nome ?? "Nodo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Annulla") { chiudi() } }
        .onAppear {
            guard nodi.isEmpty else { return }
            let figli = (try? pacchetto.archivio.nodi(figliDi: genitore?.id)) ?? []
            nodi = figli.map { Ramo(nodo: $0, figli: !((try? pacchetto.archivio.nodi(figliDi: $0.id)) ?? []).isEmpty) }
        }
    }

    private func voceNodo(_ nodo: Nodo) -> some View {
        HStack {
            Text(nodo.nome)
            Spacer()
            Text(Testi.numero(nodo.quantiColRamo)).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
