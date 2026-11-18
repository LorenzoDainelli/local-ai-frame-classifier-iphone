import Foundation

public final class LettoreCifrato {

    public let dimensione: Int
    private let chiave: Chiave
    private let posto: String
    private let file: FileHandle
    private let inizio: UInt64
    private let prefisso: Data
    private let versione: Int
    private let blocchi: Int
    private let serratura = NSLock()
    private var ultimo: (numero: Int, dati: Data)?

    init(chiave: Chiave, url: URL, posto: String) throws {
        let file = try FileHandle(forReadingFrom: url)
        do {
            let testa = try file.read(upToCount: Chiave.firma.count + 2) ?? Data()
            guard testa.count == Chiave.firma.count + 2, testa.prefix(Chiave.firma.count) == Chiave.firma
            else { throw ErroreVisore.fileEstraneo }
            let quanto = Int(testa[testa.startIndex + Chiave.firma.count]) << 8
                | Int(testa[testa.startIndex + Chiave.firma.count + 1])
            let grezza = try file.read(upToCount: quanto) ?? Data()
            guard grezza.count == quanto,
                  let campi = try? JSONSerialization.jsonObject(with: grezza) as? [String: Any],
                  let versione = campi["versione"] as? Int else { throw ErroreVisore.fileRovinato }
            if versione > Chiave.versioneLetta { throw ErroreVisore.versioneNuova }
            guard versione == Chiave.versioneLetta, campi["blocco"] as? Int == Chiave.blocco,
                  let dimensione = campi["dimensione"] as? Int, dimensione >= 0,
                  let esa = campi["prefisso"] as? String, let prefisso = Data(esadecimale: esa),
                  prefisso.count == 8 else { throw ErroreVisore.fileRovinato }
            let blocchi = dimensione == 0 ? 1 : (dimensione + Chiave.blocco - 1) / Chiave.blocco
            let inizio = UInt64(testa.count + quanto)
            guard try file.seekToEnd() == inizio + UInt64(dimensione + blocchi * Chiave.sigillo)
            else { throw ErroreVisore.fileRovinato }
            self.chiave = chiave
            self.posto = posto
            self.file = file
            self.inizio = inizio
            self.prefisso = prefisso
            self.versione = versione
            self.dimensione = dimensione
            self.blocchi = blocchi
        } catch {
            try? file.close()
            throw error
        }
    }

    deinit { try? file.close() }

    public func leggi(da: Int, quanti: Int) throws -> Data {
        guard da >= 0, quanti >= 0, da <= dimensione else { throw ErroreVisore.fileRovinato }
        let fine = min(dimensione, da + quanti)
        var uscita = Data(capacity: fine - da)
        var dove = da
        while dove < fine {
            let numero = dove / Chiave.blocco
            let chiaro = try blocco(numero)
            let dentro = dove - numero * Chiave.blocco
            let presi = min(chiaro.count - dentro, fine - dove)
            uscita.append(chiaro[(chiaro.startIndex + dentro)..<(chiaro.startIndex + dentro + presi)])
            dove += presi
        }
        return uscita
    }

    private func blocco(_ numero: Int) throws -> Data {
        serratura.lock()
        defer { serratura.unlock() }
        if let ultimo, ultimo.numero == numero { return ultimo.dati }
        guard numero < blocchi else { throw ErroreVisore.fileRovinato }
        let chiaro = min(Chiave.blocco, dimensione - numero * Chiave.blocco)
        try file.seek(toOffset: inizio + UInt64(numero * (Chiave.blocco + Chiave.sigillo)))
        let pezzo = try file.read(upToCount: chiaro + Chiave.sigillo) ?? Data()
        guard pezzo.count == chiaro + Chiave.sigillo else { throw ErroreVisore.fileRovinato }
        let aad = Chiave.accompagnamento(numero, numero == blocchi - 1, dimensione, versione, posto)
        let dati = try chiave.apriBlocco(pezzo, nonce: Chiave.nonce(prefisso, numero), aad: aad)
        ultimo = (numero, dati)
        return dati
    }
}
