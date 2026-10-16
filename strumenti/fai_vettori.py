import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from officina.telefono import cifratura, formato

PASSWORD = "cavallo-finto-42"
SALE = bytes(range(16))
COSTO = 2 ** 15


def principale(dove: Path) -> None:
    dove.mkdir(parents=True, exist_ok=True)
    chiave = cifratura.Chiave.dalla_password(PASSWORD, SALE, COSTO)
    carta = {
        "telefono": "telefono finto", "archivio": "archivio finto",
        "sale": SALE.hex(), "prova": chiave.prova(), "versione_formato": formato.VERSIONE_FORMATO,
        "stato": "completo", "quanti_scatti": 2, "quanti_video": 0,
        "dal_giorno": "2020-01-01", "al_giorno": "2020-01-02", "kdf": "scrypt",
        "n": COSTO, "r": 8, "p": 1, "blocco": cifratura.BLOCCO, "cifra": "AES-256-GCM",
    }
    (dove / "visore.json").write_text(json.dumps(carta, indent=2) + "\n", encoding="utf-8")
    casi = {
        "vuoto": b"",
        "corto": "ciao dal visore finto".encode("utf-8"),
        "lungo": bytes((i * 7 + 3) % 256 for i in range(cifratura.BLOCCO + 123)),
    }
    elenco = {}
    for nome, chiaro in casi.items():
        posto = f"foto/ab/{nome}"
        (dove / f"{nome}.bin").write_bytes(chiave.cifra_byte(chiaro, posto))
        elenco[nome] = {"posto": posto, "dimensione": len(chiaro),
                        "impronta": __import__("hashlib").sha256(chiaro).hexdigest()}
    (dove / "elenco.json").write_text(json.dumps(elenco, indent=2) + "\n", encoding="utf-8")
    (dove / "chiave.hex").write_text(chiave._byte.hex() + "\n", encoding="utf-8")


if __name__ == "__main__":
    principale(Path(sys.argv[1]))
