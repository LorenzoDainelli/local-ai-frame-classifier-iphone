import Foundation

public enum NodiColCuore {
    public static func chiave(archivio: String) -> String { "visore.nodi.cuore." + archivio }

    public static func leggi(_ testo: String) -> [Int64] {
        var visti = Set<Int64>()
        return testo.split(separator: ",").compactMap { Int64($0.trimmingCharacters(in: .whitespaces)) }
            .filter { visti.insert($0).inserted }
    }

    public static func scrivi(_ ids: [Int64]) -> String {
        leggi(ids.map(String.init).joined(separator: ",")).map(String.init).joined(separator: ",")
    }

    public static func cambia(_ testo: String, _ id: Int64) -> String {
        var ids = leggi(testo)
        if let i = ids.firstIndex(of: id) { ids.remove(at: i) } else { ids.append(id) }
        return scrivi(ids)
    }

    public static func ha(_ testo: String, _ id: Int64) -> Bool { leggi(testo).contains(id) }
}
