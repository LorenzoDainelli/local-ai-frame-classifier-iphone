import CommonCrypto
import Foundation

public enum Scrypt {

    public static func deriva(password: Data, sale: Data, n: Int, r: Int, p: Int,
                              lunghezza: Int) throws -> Data {
        guard n > 1, n & (n - 1) == 0, r > 0, p > 0 else { throw ErroreVisore.parametriStrani }
        let b = pbkdf2(password: password, sale: sale, lunghezza: p * 128 * r)
        var blocchi = [UInt32](repeating: 0, count: b.count / 4)
        b.withUnsafeBytes { grezzo in
            for i in 0..<blocchi.count {
                blocchi[i] = UInt32(littleEndian: grezzo.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self))
            }
        }
        let parole = 32 * r
        var v = [UInt32](repeating: 0, count: parole * n)
        var x = [UInt32](repeating: 0, count: parole)
        var y = [UInt32](repeating: 0, count: parole)
        for k in 0..<p {
            let inizio = k * parole
            for i in 0..<parole { x[i] = blocchi[inizio + i] }
            for i in 0..<n {
                for j in 0..<parole { v[i * parole + j] = x[j] }
                mescola(&x, &y, r)
            }
            for _ in 0..<n {
                let j = Int(x[(2 * r - 1) * 16] & UInt32(n - 1))
                for t in 0..<parole { x[t] ^= v[j * parole + t] }
                mescola(&x, &y, r)
            }
            for i in 0..<parole { blocchi[inizio + i] = x[i] }
        }
        var uscita = Data(count: b.count)
        uscita.withUnsafeMutableBytes { grezzo in
            for i in 0..<blocchi.count {
                grezzo.storeBytes(of: blocchi[i].littleEndian, toByteOffset: i * 4, as: UInt32.self)
            }
        }
        return pbkdf2(password: password, sale: uscita, lunghezza: lunghezza)
    }

    static func pbkdf2(password: Data, sale: Data, lunghezza: Int) -> Data {
        var uscita = Data(count: lunghezza)
        uscita.withUnsafeMutableBytes { u in
            password.withUnsafeBytes { pw in
                sale.withUnsafeBytes { s in
                    _ = CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        pw.baseAddress?.assumingMemoryBound(to: CChar.self), password.count,
                        s.baseAddress?.assumingMemoryBound(to: UInt8.self), sale.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 1,
                        u.baseAddress?.assumingMemoryBound(to: UInt8.self), lunghezza)
                }
            }
        }
        return uscita
    }

    private static func mescola(_ b: inout [UInt32], _ y: inout [UInt32], _ r: Int) {
        var x = Array(b[((2 * r - 1) * 16)..<(2 * r * 16)])
        for i in 0..<(2 * r) {
            for j in 0..<16 { x[j] ^= b[i * 16 + j] }
            salsa8(&x)
            let dove = (i % 2 == 0 ? i / 2 : r + i / 2) * 16
            for j in 0..<16 { y[dove + j] = x[j] }
        }
        b = y
    }

    private static func salsa8(_ b: inout [UInt32]) {
        var x = b
        @inline(__always) func g(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
            x[b] ^= (x[a] &+ x[d]).ruota(7)
            x[c] ^= (x[b] &+ x[a]).ruota(9)
            x[d] ^= (x[c] &+ x[b]).ruota(13)
            x[a] ^= (x[d] &+ x[c]).ruota(18)
        }
        for _ in 0..<4 {
            g(0, 4, 8, 12); g(5, 9, 13, 1); g(10, 14, 2, 6); g(15, 3, 7, 11)
            g(0, 1, 2, 3); g(5, 6, 7, 4); g(10, 11, 8, 9); g(15, 12, 13, 14)
        }
        for i in 0..<16 { b[i] = b[i] &+ x[i] }
    }
}

private extension UInt32 {
    func ruota(_ n: UInt32) -> UInt32 { (self << n) | (self >> (32 - n)) }
}
