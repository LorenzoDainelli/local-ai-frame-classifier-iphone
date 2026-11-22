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

struct Cerca: View {
    let pacchetto: Pacchetto
    let chiudi: () -> Void
    @State private var testo = ""
    @State private var cercato = ""
    @State private var filtro = Filtro()
    @State private var recenti = Recenti.tutte()
    @State private var anni: [Anno] = []
    @State private var luoghi: [Luogo] = []
    @State private var persone: [Persona] = []
    @State private var scelta: Scelta?
    @State private var conParole = false
    @FocusState private var dentro: Bool

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
        VStack(spacing: 0) {
            barra
            if !filtro.vuoto { pilloleAttive }
            Group {
                if f.vuoto {
                    inizio
                } else {
                    GrigliaGiorni(pacchetto: pacchetto, filtro: f, titolo: "Risultati",
                                  sottotitolo: Frase.cerco(f.parole, conParole: conParole),
                                  testa: AnyView(trovati), vuota: nienteDa(f), conIndietro: false)
                        .id(f)
                        .transition(.opacity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Tinta.fondo.ignoresSafeArea())
        .senzaBarraDiSistema()
        .animation(Moto.passo, value: f.vuoto)
        .animation(Moto.passo, value: filtro)
        .task(id: testo) {
            try? await Task.sleep(for: .milliseconds(250))
            if !Task.isCancelled { cercato = testo }
        }
        .sheet(item: $scelta) { s in
            NavigationStack { foglio(s) }
                .environment(\.vaiA, nil)
                .presentationDetents([.medium, .large])
                .foglioStile()
        }
        .onAppear {
            if anni.isEmpty {
                anni = (try? pacchetto.archivio.anni()) ?? []
                luoghi = (try? pacchetto.archivio.luoghi()) ?? []
                persone = (try? pacchetto.archivio.persone()) ?? []
                conParole = pacchetto.archivio.ciSonoParole()
            }
            if filtro.vuoto, testo.isEmpty { dentro = true }
        }
    }

    private var barra: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .medium)).foregroundStyle(Tinta.tenue)
                TextField("", text: $testo, prompt: Text("Nodi, note, persone, luoghi, anni").foregroundStyle(Tinta.tenue))
                    .font(.system(size: 16))
                    .foregroundStyle(Tinta.ink)
                    .focused($dentro)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { ricorda() }
                if !testo.isEmpty {
                    Button {
                        testo = ""
                        cercato = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(Tinta.tenue)
                    }
                    .buttonStyle(Premuto(quanto: 0.85))
                    .accessibilityLabel("Svuota")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Tinta.superficie, in: Capsule())
            .overlay(Capsule().stroke(dentro ? Tinta.accento : Tinta.lineaForte, lineWidth: dentro ? 1 : 0.5))
            .animation(Moto.gesto, value: dentro)
            .animation(Moto.gesto, value: testo.isEmpty)
            aggiungi
            Button("Chiudi", action: chiudi)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Tinta.accento)
                .buttonStyle(Premuto())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var pilloleAttive: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(pillole) { p in
                    Pillola(testo: p.testo, simbolo: p.simbolo, scelta: true, togli: p.togli)
                        .transition(.scale.combined(with: .opacity))
                }
                Button("Togli tutto") { withAnimation(Moto.passo) { filtro = Filtro() } }
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Tinta.accento)
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 8)
    }

    private var inizio: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !recenti.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("RICERCHE RECENTI").etichettaMaiuscola()
                            Spacer()
                            Button("Cancella") {
                                Recenti.dimentica()
                                withAnimation(Moto.passo) { recenti = [] }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tinta.accento)
                        }
                        .padding(.horizontal, 4)
                        Scheda {
                            ForEach(Array(recenti.enumerated()), id: \.element) { i, r in
                                if i > 0 { Separa(rientro: 46) }
                                HStack(spacing: 12) {
                                    Button {
                                        testo = r
                                        cercato = r
                                        dentro = false
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "clock.arrow.circlepath").font(.system(size: 14))
                                                .foregroundStyle(Tinta.tenue).frame(width: 20)
                                            Text(r).font(.system(size: 15.5)).foregroundStyle(Tinta.ink).lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(Premuto(quanto: 0.98))
                                    Button {
                                        Recenti.togli(r)
                                        withAnimation(Moto.passo) { recenti = Recenti.tutte() }
                                    } label: {
                                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Tinta.tenue).frame(width: 30, height: 30).contentShape(Rectangle())
                                    }
                                    .buttonStyle(Premuto(quanto: 0.85))
                                    .accessibilityLabel("Togli \(r)")
                                }
                                .padding(.horizontal, 14)
                            }
                        }
                    }
                }
                if !anni.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ANNI").etichettaMaiuscola().padding(.horizontal, 4)
                        Fila(spazio: 6) {
                            ForEach(anni) { a in
                                Button { usa { $0.anno = a.anno } } label: { Pillola(testo: a.anno, simbolo: "calendar") }
                                    .buttonStyle(Premuto())
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("FILTRI").etichettaMaiuscola().padding(.horizontal, 4)
                    Fila(spazio: 6) {
                        ForEach(Frase.generi) { g in
                            Button { usa { $0.genere = g.id } } label: { Pillola(testo: g.nome, simbolo: simbolo(g.id)) }
                                .buttonStyle(Premuto())
                        }
                        if !luoghi.isEmpty {
                            Button { scelta = .luogo } label: { Pillola(testo: "Luogo…", simbolo: "mappin.and.ellipse") }
                                .buttonStyle(Premuto())
                        }
                        if !persone.isEmpty {
                            Button { scelta = .persona } label: { Pillola(testo: "Persona…", simbolo: "person") }
                                .buttonStyle(Premuto())
                        }
                        Button { scelta = .nodo } label: { Pillola(testo: "Nodo…", simbolo: "square.grid.2x2") }
                            .buttonStyle(Premuto())
                    }
                }
                Text("Scrivi una parola, oppure tocca un filtro. I filtri si sommano: si tolgono con la loro ×.")
                    .font(.system(size: 13)).foregroundStyle(Tinta.tenue)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 30)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private func simbolo(_ genere: String) -> String {
        switch genere {
        case "live": return "livephoto"
        case "video": return "video"
        default: return "photo"
        }
    }

    @ViewBuilder
    private var trovati: some View {
        if let t = try? pacchetto.archivio.trovati(cercato), !t.vuoto {
            Scheda {
                let voci = vociDa(t)
                ForEach(Array(voci.enumerated()), id: \.element.id) { i, v in
                    if i > 0 { Separa(rientro: 58) }
                    v.vista
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private struct VoceTrovata: Identifiable {
        let id: String
        let vista: AnyView
    }

    private func vociDa(_ t: Trovati) -> [VoceTrovata] {
        var v: [VoceTrovata] = []
        for p in t.persone {
            v.append(VoceTrovata(id: "p\(p.id)", vista: AnyView(Collegamento(p) {
                Riga(titolo: p.nome, sottotitolo: "Persona", numero: p.quanti) {
                    Volto(pacchetto: pacchetto, persona: p, lato: 32)
                }
            }.buttonStyle(Premibile()))))
        }
        for n in t.nodi {
            v.append(VoceTrovata(id: "n\(n.id)", vista: AnyView(Collegamento(n) {
                Riga(titolo: n.nome, sottotitolo: "Nodo", numero: n.quantiColRamo) {
                    Copertina(pacchetto: pacchetto, nodo: n, lato: 32)
                }
            }.buttonStyle(Premibile()))))
        }
        for l in t.luoghi {
            v.append(VoceTrovata(id: "l\(l.id)", vista: AnyView(Button { usa { $0.luogo = l.id } } label: {
                Riga(titolo: l.nome, sottotitolo: "Luogo: aggiungi come filtro", numero: l.quanti) { Icona(simbolo: "mappin.and.ellipse") }
            }.buttonStyle(Premibile()))))
        }
        for a in t.anni {
            v.append(VoceTrovata(id: "a\(a.anno)", vista: AnyView(Button { usa { $0.anno = a.anno } } label: {
                Riga(titolo: a.anno, sottotitolo: "Anno: aggiungi come filtro", numero: a.quanti) { Icona(simbolo: "calendar") }
            }.buttonStyle(Premibile()))))
        }
        return v
    }

    private struct Icona: View {
        let simbolo: String

        var body: some View {
            Image(systemName: simbolo).font(.system(size: 14, weight: .medium))
                .foregroundStyle(Tinta.accento)
                .frame(width: 32, height: 32)
                .background(Tinta.alone, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    struct Pill: Identifiable {
        let id: String
        let testo: String
        let simbolo: String
        let togli: () -> Void
    }

    private var pillole: [Pill] {
        var uscita: [Pill] = []
        for id in filtro.persone {
            let nome = persone.first { $0.id == id }?.nome ?? (try? pacchetto.archivio.persona(id))?.nome ?? "?"
            uscita.append(Pill(id: "persona-\(id)", testo: nome, simbolo: "person",
                               togli: { withAnimation(Moto.passo) { filtro.persone.removeAll { $0 == id } } }))
        }
        if let n = filtro.nodo {
            let nome = (try? pacchetto.archivio.nodo(n))?.nome ?? "?"
            uscita.append(Pill(id: "nodo", testo: filtro.soloQui ? "\(nome) (solo qui)" : nome, simbolo: "square.grid.2x2",
                               togli: { withAnimation(Moto.passo) { filtro.nodo = nil; filtro.soloQui = false } }))
        }
        if let l = filtro.luogo {
            uscita.append(Pill(id: "luogo", testo: luoghi.first { $0.id == l }?.nome ?? "?", simbolo: "mappin.and.ellipse",
                               togli: { withAnimation(Moto.passo) { filtro.luogo = nil } }))
        }
        if let a = filtro.anno {
            uscita.append(Pill(id: "anno", testo: a, simbolo: "calendar",
                               togli: { withAnimation(Moto.passo) { filtro.anno = nil } }))
        }
        if let g = filtro.genere {
            uscita.append(Pill(id: "genere", testo: Frase.genere(g), simbolo: simbolo(g),
                               togli: { withAnimation(Moto.passo) { filtro.genere = nil } }))
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
        dentro = false
        withAnimation(Moto.passo) {
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
            FacciaTondo(simbolo: "line.3.horizontal.decrease")
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

struct VoceScelta: View {
    let nome: String
    let quanti: Int
    var simbolo: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let simbolo {
                Image(systemName: simbolo).font(.system(size: 14)).foregroundStyle(Tinta.accento).frame(width: 22)
            }
            Text(nome).font(.system(size: 15.5)).foregroundStyle(Tinta.ink)
                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).layoutPriority(1)
            Text(Testi.numero(quanti)).font(.system(size: 13)).foregroundStyle(Tinta.tenue).monospacedDigit()
                .fixedSize()
        }
        .contentShape(Rectangle())
    }
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
                VoceScelta(nome: v.nome, quanti: v.quanti)
            }
            .listRowBackground(Tinta.fondo)
        }
        .scrollContentBackground(.hidden)
        .background(Tinta.superficie)
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
                    VoceScelta(nome: "Tutto «\(genitore.nome)»", quanti: genitore.quantiColRamo, simbolo: "checkmark.circle")
                }
                .listRowBackground(Tinta.fondo)
            }
            ForEach(nodi) { voce in
                let nodo = voce.nodo
                Group {
                    if voce.figli {
                        NavigationLink {
                            SceltaNodo(pacchetto: pacchetto, genitore: nodo, scegli: scegli)
                        } label: {
                            VoceScelta(nome: nodo.nome, quanti: nodo.quantiColRamo)
                        }
                    } else {
                        Button {
                            scegli(nodo)
                        } label: {
                            VoceScelta(nome: nodo.nome, quanti: nodo.quantiColRamo)
                        }
                    }
                }
                .listRowBackground(Tinta.fondo)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Tinta.superficie)
        .navigationTitle(genitore?.nome ?? "Nodo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Annulla") { chiudi() } }
        .onAppear {
            guard nodi.isEmpty else { return }
            let figli = (try? pacchetto.archivio.nodi(figliDi: genitore?.id)) ?? []
            nodi = figli.map { Ramo(nodo: $0, figli: !((try? pacchetto.archivio.nodi(figliDi: $0.id)) ?? []).isEmpty) }
        }
    }
}
