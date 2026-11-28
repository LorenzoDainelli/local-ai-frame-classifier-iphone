import CommonCrypto
import Foundation

public enum Scrypt {

    public static func deriva(password: Data, sale: Data, n: Int, r: Int, p: Int,
                              lunghezza: Int) throws -> Data {
        guard n > 1, n & (n - 1) == 0, r > 0, p > 0 else { throw ErroreVisore.parametriStrani }
        var b = pbkdf2(password: password, sale: sale, lunghezza: p * 128 * r)
        let parole = 32 * r
        let v = UnsafeMutablePointer<UInt32>.allocate(capacity: parole * n)
        let x = UnsafeMutablePointer<UInt32>.allocate(capacity: parole)
        let y = UnsafeMutablePointer<UInt32>.allocate(capacity: parole)
        let t = UnsafeMutablePointer<UInt32>.allocate(capacity: 16)
        defer {
            v.update(repeating: 0, count: parole * n)
            x.update(repeating: 0, count: parole)
            y.update(repeating: 0, count: parole)
            t.update(repeating: 0, count: 16)
            v.deallocate()
            x.deallocate()
            y.deallocate()
            t.deallocate()
        }
        let maschera = UInt32(truncatingIfNeeded: n - 1)
        let ultimo = (2 * r - 1) * 16
        b.withUnsafeMutableBytes { grezzo in
            for k in 0..<p {
                let inizio = k * parole * 4
                for i in 0..<parole {
                    x[i] = UInt32(littleEndian: grezzo.loadUnaligned(fromByteOffset: inizio + i * 4, as: UInt32.self))
                }
                for i in 0..<n {
                    (v + i * parole).update(from: x, count: parole)
                    mescola(x, y, t, r)
                }
                for _ in 0..<n {
                    let j = Int(x[ultimo] & maschera)
                    let riga = v + j * parole
                    for q in 0..<parole { x[q] ^= riga[q] }
                    mescola(x, y, t, r)
                }
                for i in 0..<parole {
                    grezzo.storeBytes(of: x[i].littleEndian, toByteOffset: inizio + i * 4, as: UInt32.self)
                }
            }
        }
        defer { b.resetBytes(in: 0..<b.count) }
        return pbkdf2(password: password, sale: b, lunghezza: lunghezza)
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

    @inline(__always)
    private static func mescola(_ b: UnsafeMutablePointer<UInt32>, _ y: UnsafeMutablePointer<UInt32>,
                                _ t: UnsafeMutablePointer<UInt32>, _ r: Int) {
        t.update(from: b + (2 * r - 1) * 16, count: 16)
        for i in 0..<(2 * r) {
            let pezzo = b + i * 16
            for j in 0..<16 { t[j] ^= pezzo[j] }
            salsa8(t)
            let dove = (i % 2 == 0 ? i / 2 : r + i / 2) * 16
            (y + dove).update(from: t, count: 16)
        }
        b.update(from: y, count: 32 * r)
    }

    @inline(__always)
    private static func salsa8(_ b: UnsafeMutablePointer<UInt32>) {
        var x0 = b[0], x1 = b[1], x2 = b[2], x3 = b[3], x4 = b[4], x5 = b[5], x6 = b[6], x7 = b[7]
        var x8 = b[8], x9 = b[9], x10 = b[10], x11 = b[11], x12 = b[12], x13 = b[13], x14 = b[14], x15 = b[15]
        for _ in 0..<4 {
            x4 ^= (x0 &+ x12).ruota(7); x8 ^= (x4 &+ x0).ruota(9)
            x12 ^= (x8 &+ x4).ruota(13); x0 ^= (x12 &+ x8).ruota(18)
            x9 ^= (x5 &+ x1).ruota(7); x13 ^= (x9 &+ x5).ruota(9)
            x1 ^= (x13 &+ x9).ruota(13); x5 ^= (x1 &+ x13).ruota(18)
            x14 ^= (x10 &+ x6).ruota(7); x2 ^= (x14 &+ x10).ruota(9)
            x6 ^= (x2 &+ x14).ruota(13); x10 ^= (x6 &+ x2).ruota(18)
            x3 ^= (x15 &+ x11).ruota(7); x7 ^= (x3 &+ x15).ruota(9)
            x11 ^= (x7 &+ x3).ruota(13); x15 ^= (x11 &+ x7).ruota(18)
            x1 ^= (x0 &+ x3).ruota(7); x2 ^= (x1 &+ x0).ruota(9)
            x3 ^= (x2 &+ x1).ruota(13); x0 ^= (x3 &+ x2).ruota(18)
            x6 ^= (x5 &+ x4).ruota(7); x7 ^= (x6 &+ x5).ruota(9)
            x4 ^= (x7 &+ x6).ruota(13); x5 ^= (x4 &+ x7).ruota(18)
            x11 ^= (x10 &+ x9).ruota(7); x8 ^= (x11 &+ x10).ruota(9)
            x9 ^= (x8 &+ x11).ruota(13); x10 ^= (x9 &+ x8).ruota(18)
            x12 ^= (x15 &+ x14).ruota(7); x13 ^= (x12 &+ x15).ruota(9)
            x14 ^= (x13 &+ x12).ruota(13); x15 ^= (x14 &+ x13).ruota(18)
        }
        b[0] &+= x0; b[1] &+= x1; b[2] &+= x2; b[3] &+= x3
        b[4] &+= x4; b[5] &+= x5; b[6] &+= x6; b[7] &+= x7
        b[8] &+= x8; b[9] &+= x9; b[10] &+= x10; b[11] &+= x11
        b[12] &+= x12; b[13] &+= x13; b[14] &+= x14; b[15] &+= x15
    }
}

private extension UInt32 {
    func ruota(_ n: UInt32) -> UInt32 { (self << n) | (self >> (32 - n)) }
}
