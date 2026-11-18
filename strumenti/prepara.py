from __future__ import annotations

import base64
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

import fai_icona  # noqa: E402

ICONA = RADICE / "Visore" / "Assets.xcassets" / "AppIcon.appiconset" / "icona.png"


def spacchetta(testo: str, dove: Path) -> Path:
    nome = None
    quanti = 0
    pezzi: list[str] = []

    def chiudi() -> None:
        if nome is None:
            return
        dati = base64.b64decode("".join(pezzi))
        if len(dati) != quanti:
            raise ValueError(f"{nome}: {quanti} byte attesi, {len(dati)} letti")
        fuori = dove.joinpath(*nome.split("/"))
        if not fuori.resolve().is_relative_to(dove.resolve()):
            raise ValueError(f"{nome} esce dalla cartella")
        fuori.parent.mkdir(parents=True, exist_ok=True)
        fuori.write_bytes(dati)

    for riga in testo.splitlines():
        if riga.startswith("#"):
            continue
        if not riga.strip():
            chiudi()
            nome, pezzi = None, []
            continue
        if nome is None:
            pezzo, _, misura = riga.rpartition(" ")
            nome, quanti, pezzi = pezzo, int(misura), []
        else:
            pezzi.append(riga.strip())
    chiudi()
    return dove


def prepara(radice: Path = RADICE, icona: Path = ICONA) -> None:
    spacchetta((radice / "Prova.txt").read_text(encoding="utf-8"), radice / "Prova")
    fai_icona.scrivi_iphone(icona)


if __name__ == "__main__":
    prepara()
