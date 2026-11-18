import Foundation

public final class Pacchetto {

    public static let versioneFormatoLetta = 2

    public let cartella: URL
    public let carta: Carta
    public let archivio: Archivio
    private let chiave: Chiave

    public init(cartella: URL, password: String) throws {
        let carta = try Carta.leggi(cartella: cartella)
        guard carta.versioneFormato <= Pacchetto.versioneFormatoLetta else { throw ErroreVisore.versioneNuova }
        guard carta.completa else { throw ErroreVisore.cartaRovinata }
        let chiave = try Chiave.dallaPassword(password, carta: carta)
        var chiaro = try chiave.decifra(Data(contentsOf: cartella.appendingPathComponent("dati.db")), posto: "dati.db")
        defer { chiaro.resetBytes(in: 0..<chiaro.count) }
        self.cartella = cartella
        self.carta = carta
        self.chiave = chiave
        self.archivio = try Archivio(dati: chiaro)
    }

    public func apri(_ posto: String) throws -> Data {
        guard Pacchetto.postoSicuro(posto) else { throw ErroreVisore.fileEstraneo }
        return try chiave.decifra(Data(contentsOf: cartella.appendingPathComponent(posto)), posto: posto)
    }

    public func apriInUnFile(_ posto: String, estensione: String) throws -> URL {
        guard Pacchetto.postoSicuro(posto) else { throw ErroreVisore.fileEstraneo }
        let dove = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(estensione)
        try chiave.decifraFile(da: cartella.appendingPathComponent(posto), a: dove, posto: posto)
        return dove
    }

    static func postoSicuro(_ posto: String) -> Bool {
        let pezzi = posto.split(separator: "/", omittingEmptySubsequences: false)
        guard let primo = pezzi.first, ["foto", "mini", "volti"].contains(primo), pezzi.count <= 3 else { return false }
        return pezzi.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") }
    }
}
