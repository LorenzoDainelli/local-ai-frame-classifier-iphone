import Foundation

public struct Carta: Codable, Equatable {
    public var telefono: String
    public var archivio: String
    public var sale: String
    public var prova: String
    public var versioneFormato: Int
    public var stato: String
    public var quantiScatti: Int
    public var quantiVideo: Int
    public var dalGiorno: String
    public var alGiorno: String
    public var kdf: String
    public var n: Int
    public var r: Int
    public var p: Int
    public var blocco: Int
    public var cifra: String

    enum CodingKeys: String, CodingKey {
        case telefono, archivio, sale, prova, stato, kdf, n, r, p, blocco, cifra
        case versioneFormato = "versione_formato"
        case quantiScatti = "quanti_scatti"
        case quantiVideo = "quanti_video"
        case dalGiorno = "dal_giorno"
        case alGiorno = "al_giorno"
    }

    public var completa: Bool { stato == "completo" }

    public static func leggi(cartella: URL) throws -> Carta {
        guard let dati = try? Data(contentsOf: cartella.appendingPathComponent("visore.json")),
              let carta = try? JSONDecoder().decode(Carta.self, from: dati)
        else { throw ErroreVisore.cartaRovinata }
        return carta
    }
}
