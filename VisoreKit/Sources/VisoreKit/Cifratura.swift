import CryptoKit
import Foundation
import Security

public enum ErroreVisore: Error, Equatable {
    case parametriStrani
    case passwordSbagliata
    case fileEstraneo
    case fileRovinato
    case versioneNuova
    case cartaRovinata
    case archivioIlleggibile
}

public struct Chiave {

    static let firma = Data("VISORE-FILE\u{0}".utf8)
    static let prova = Data("officina-visore-prova".utf8)
    static let blocco = 1024 * 1024
    static let sigillo = 16
    static let versioneLetta = 2

    let chiave: SymmetricKey

    public init(byte: Data) throws {
        guard byte.count == 32 else { throw ErroreVisore.parametriStrani }
        chiave = SymmetricKey(data: byte)
    }

    public static func dallaPassword(_ password: String, carta: Carta) throws -> Chiave {
        guard carta.kdf == "scrypt", carta.cifra == "AES-256-GCM", carta.blocco == blocco,
              [1 << 15, 1 << 16, 1 << 17, 1 << 18].contains(carta.n), carta.r == 8, carta.p == 1,
              let sale = Data(esadecimale: carta.sale) else { throw ErroreVisore.cartaRovinata }
        let byte = try Scrypt.deriva(password: Data(password.utf8), sale: sale,
                                     n: carta.n, r: carta.r, p: carta.p, lunghezza: 32)
        let chiave = try Chiave(byte: byte)
        guard chiave.apre(prova: carta.prova) else { throw ErroreVisore.passwordSbagliata }
        return chiave
    }

    public func apre(prova esa: String) -> Bool {
        guard let cifrato = Data(esadecimale: esa),
              let aperto = try? apri(cifrato, nonce: Chiave.nonce(Data(count: 8), 0),
                                     aad: Chiave.accompagnamento(0, true, Chiave.prova.count, 1, nil))
        else { return false }
        return aperto == Chiave.prova
    }

    public func decifra(_ dati: Data, posto: String) throws -> Data {
        guard dati.count >= Chiave.firma.count + 2,
              dati.prefix(Chiave.firma.count) == Chiave.firma else { throw ErroreVisore.fileEstraneo }
        var dove = dati.startIndex + Chiave.firma.count
        let quanto = Int(dati[dove]) << 8 | Int(dati[dove + 1])
        dove += 2
        guard dati.endIndex - dove >= quanto,
              let testa = try? JSONSerialization.jsonObject(with: dati[dove..<(dove + quanto)]) as? [String: Any]
        else { throw ErroreVisore.fileRovinato }
        dove += quanto
        guard let versione = testa["versione"] as? Int else { throw ErroreVisore.fileRovinato }
        if versione > Chiave.versioneLetta { throw ErroreVisore.versioneNuova }
        guard versione == Chiave.versioneLetta, testa["blocco"] as? Int == Chiave.blocco,
              let dimensione = testa["dimensione"] as? Int, dimensione >= 0,
              let esa = testa["prefisso"] as? String, let prefisso = Data(esadecimale: esa),
              prefisso.count == 8 else { throw ErroreVisore.fileRovinato }
        let blocchi = dimensione == 0 ? 1 : (dimensione + Chiave.blocco - 1) / Chiave.blocco
        guard dati.endIndex - dove == dimensione + blocchi * Chiave.sigillo else { throw ErroreVisore.fileRovinato }
        var uscita = Data(capacity: dimensione)
        for numero in 0..<blocchi {
            let chiaro = min(Chiave.blocco, dimensione - numero * Chiave.blocco)
            let pezzo = dati[dove..<(dove + chiaro + Chiave.sigillo)]
            dove += chiaro + Chiave.sigillo
            let aad = Chiave.accompagnamento(numero, numero == blocchi - 1, dimensione, versione, posto)
            uscita.append(try apri(Data(pezzo), nonce: Chiave.nonce(prefisso, numero), aad: aad))
        }
        return uscita
    }

    public func decifraFile(da sorgente: URL, a destinazione: URL, posto: String) throws {
        let dentro = try FileHandle(forReadingFrom: sorgente)
        defer { try? dentro.close() }
        let inizio = try dentro.read(upToCount: Chiave.firma.count + 2) ?? Data()
        guard inizio.count == Chiave.firma.count + 2, inizio.prefix(Chiave.firma.count) == Chiave.firma
        else { throw ErroreVisore.fileEstraneo }
        let quanto = Int(inizio[inizio.startIndex + Chiave.firma.count]) << 8 | Int(inizio[inizio.startIndex + Chiave.firma.count + 1])
        let grezza = try dentro.read(upToCount: quanto) ?? Data()
        guard grezza.count == quanto,
              let testa = try? JSONSerialization.jsonObject(with: grezza) as? [String: Any],
              let versione = testa["versione"] as? Int else { throw ErroreVisore.fileRovinato }
        if versione > Chiave.versioneLetta { throw ErroreVisore.versioneNuova }
        guard versione == Chiave.versioneLetta, testa["blocco"] as? Int == Chiave.blocco,
              let dimensione = testa["dimensione"] as? Int, dimensione >= 0,
              let esa = testa["prefisso"] as? String, let prefisso = Data(esadecimale: esa),
              prefisso.count == 8 else { throw ErroreVisore.fileRovinato }
        let blocchi = dimensione == 0 ? 1 : (dimensione + Chiave.blocco - 1) / Chiave.blocco
        let attesa = UInt64(inizio.count + quanto + dimensione + blocchi * Chiave.sigillo)
        guard try dentro.seekToEnd() == attesa else { throw ErroreVisore.fileRovinato }
        try dentro.seek(toOffset: UInt64(inizio.count + quanto))
        let parziale = destinazione.appendingPathExtension("parziale")
        FileManager.default.createFile(atPath: parziale.path, contents: nil,
                                       attributes: [.protectionKey: FileProtectionType.complete])
        let fuori = try FileHandle(forWritingTo: parziale)
        do {
            for numero in 0..<blocchi {
                let chiaro = min(Chiave.blocco, dimensione - numero * Chiave.blocco)
                let pezzo = try dentro.read(upToCount: chiaro + Chiave.sigillo) ?? Data()
                guard pezzo.count == chiaro + Chiave.sigillo else { throw ErroreVisore.fileRovinato }
                let aad = Chiave.accompagnamento(numero, numero == blocchi - 1, dimensione, versione, posto)
                try fuori.write(contentsOf: apri(pezzo, nonce: Chiave.nonce(prefisso, numero), aad: aad))
            }
            try fuori.close()
            _ = try? FileManager.default.removeItem(at: destinazione)
            try FileManager.default.moveItem(at: parziale, to: destinazione)
        } catch {
            try? fuori.close()
            try? FileManager.default.removeItem(at: parziale)
            throw error
        }
    }

    public func cifra(_ dati: Data, posto: String) throws -> Data {
        var prefisso = Data(count: 8)
        let esito = prefisso.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 8, $0.baseAddress!) }
        guard esito == errSecSuccess else { throw ErroreVisore.parametriStrani }
        return try cifra(dati, posto: posto, prefisso: prefisso)
    }

    func cifra(_ dati: Data, posto: String, prefisso: Data) throws -> Data {
        guard prefisso.count == 8 else { throw ErroreVisore.parametriStrani }
        let esa = prefisso.map { String(format: "%02x", $0) }.joined()
        let testa = Data(("{\"blocco\": \(Chiave.blocco), \"cifra\": \"AES-256-GCM\", \"dimensione\": \(dati.count), "
            + "\"prefisso\": \"\(esa)\", \"versione\": \(Chiave.versioneLetta)}").utf8)
        var uscita = Chiave.firma + Chiave.grande(testa.count, 2) + testa
        uscita.reserveCapacity(uscita.count + dati.count + 64)
        var numero = 0
        var inizio = 0
        while true {
            let fine = min(inizio + Chiave.blocco, dati.count)
            let ultimo = inizio + Chiave.blocco >= dati.count
            let aad = Chiave.accompagnamento(numero, ultimo, dati.count, Chiave.versioneLetta, posto)
            let pezzo = dati.subdata(in: (dati.startIndex + inizio)..<(dati.startIndex + fine))
            do {
                let chiusa = try AES.GCM.seal(pezzo, using: chiave, nonce: AES.GCM.Nonce(data: Chiave.nonce(prefisso, numero)),
                                              authenticating: aad)
                uscita += chiusa.ciphertext + chiusa.tag
            } catch {
                throw ErroreVisore.parametriStrani
            }
            if ultimo { break }
            inizio += Chiave.blocco
            numero += 1
        }
        return uscita
    }

    func apriBlocco(_ cifrato: Data, nonce: Data, aad: Data) throws -> Data {
        try apri(cifrato, nonce: nonce, aad: aad)
    }

    private func apri(_ cifrato: Data, nonce: Data, aad: Data) throws -> Data {
        guard cifrato.count >= Chiave.sigillo else { throw ErroreVisore.fileRovinato }
        do {
            let scatola = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce),
                                                ciphertext: cifrato.dropLast(Chiave.sigillo),
                                                tag: cifrato.suffix(Chiave.sigillo))
            return try AES.GCM.open(scatola, using: chiave, authenticating: aad)
        } catch {
            throw ErroreVisore.fileRovinato
        }
    }

    static func nonce(_ prefisso: Data, _ numero: Int) -> Data {
        prefisso + grande(numero, 4)
    }

    static func accompagnamento(_ numero: Int, _ ultimo: Bool, _ dimensione: Int,
                                _ versione: Int, _ posto: String?) -> Data {
        var testa = Data("visore-\(versione)\u{0}".utf8)
        if versione >= 2 {
            let nome = Data((posto ?? "").utf8)
            testa += grande(nome.count, 2) + nome
        }
        return testa + grande(numero, 4) + Data([ultimo ? 1 : 0]) + grande(dimensione, 8)
    }

    static func grande(_ valore: Int, _ quanti: Int) -> Data {
        Data((0..<quanti).reversed().map { UInt8(truncatingIfNeeded: UInt64(valore) >> (8 * UInt64($0))) })
    }
}

extension Data {
    init?(esadecimale: String) {
        let cifre = Array(esadecimale.utf8)
        guard cifre.count % 2 == 0 else { return nil }
        var byte = [UInt8]()
        byte.reserveCapacity(cifre.count / 2)
        for i in stride(from: 0, to: cifre.count, by: 2) {
            guard let alto = Data.valore(cifre[i]), let basso = Data.valore(cifre[i + 1]) else { return nil }
            byte.append(alto << 4 | basso)
        }
        self.init(byte)
    }

    private static func valore(_ c: UInt8) -> UInt8? {
        switch c {
        case 48...57: return c - 48
        case 97...102: return c - 87
        case 65...70: return c - 55
        default: return nil
        }
    }
}
