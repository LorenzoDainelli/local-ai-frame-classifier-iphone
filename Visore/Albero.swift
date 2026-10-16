import AVKit
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
                        Griglia(pacchetto: pacchetto, scatti: (try? pacchetto.archivio.scatti(nodo: genitore.id, soloQui: soloQui)) ?? [])
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

struct Griglia: View {
    let pacchetto: Pacchetto
    let scatti: [Scatto]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                ForEach(scatti) { s in
                    NavigationLink { Dettaglio(pacchetto: pacchetto, scatto: s) } label: {
                        Miniatura(pacchetto: pacchetto, posto: s.mini ?? s.posto)
                    }
                }
            }
        }
    }
}

struct Dettaglio: View {
    let pacchetto: Pacchetto
    let scatto: Scatto
    @State private var immagine: UIImage?
    @State private var lettore: AVPlayer?
    @State private var fileVideo: URL?
    @State private var errore = false

    var body: some View {
        VStack {
            if let lettore {
                VideoPlayer(player: lettore)
            } else if let immagine {
                Image(uiImage: immagine).resizable().scaledToFit()
                    .onLongPressGesture(minimumDuration: 0.3) { Task { await muovi() } }
            } else if errore {
                Text("Questo scatto non si apre: il pacchetto va ricopiato dal computer.").multilineTextAlignment(.center)
            } else {
                ProgressView()
            }
            if let nota = scatto.nota, !nota.isEmpty { Text(nota).padding() }
        }
        .navigationTitle(scatto.giorno ?? "Senza data")
        .navigationBarTitleDisplayMode(.inline)
        .task { await carica() }
        .onDisappear {
            lettore?.pause()
            if let fileVideo { try? FileManager.default.removeItem(at: fileVideo) }
        }
    }

    private func muovi() async {
        guard let movimento = scatto.postoMovimento, lettore == nil else { return }
        let p = pacchetto
        if let url = await Task.detached(operation: { try? p.apriInUnFile(movimento, estensione: "mov") }).value {
            fileVideo = url
            lettore = AVPlayer(url: url)
            lettore?.play()
        }
    }

    private func carica() async {
        let p = pacchetto, s = scatto
        if s.genere == "video" {
            if let url = await Task.detached(operation: { try? p.apriInUnFile(s.posto, estensione: "mov") }).value {
                fileVideo = url
                lettore = AVPlayer(url: url)
            } else { errore = true }
        } else if let img = await Task.detached(operation: { (try? p.apri(s.posto)).flatMap(UIImage.init(data:)) }).value {
            immagine = img
        } else { errore = true }
    }
}
