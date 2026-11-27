from __future__ import annotations

import re
import sys
from pathlib import Path

CLASSE = re.compile(r"class\s+(\w+)\s*:\s*XCTestCase")
PROVA = re.compile(r"func\s+(test\w*)\s*\(")


def tutte(cartella: Path) -> list[tuple[str, str]]:
    trovate = []
    for file in sorted(cartella.rglob("*.swift")):
        classe = None
        for riga in file.read_text(encoding="utf-8").splitlines():
            if (c := CLASSE.search(riga)):
                classe = c.group(1)
            elif classe and (p := PROVA.search(riga)):
                trovate.append((classe, p.group(1)))
    return trovate


def mie(prove: list[tuple[str, str]], pezzo: int, quanti: int) -> list[tuple[str, str]]:
    return [prova for indice, prova in enumerate(prove) if indice % quanti == pezzo - 1]


def main() -> int:
    modo, cartella, modulo = sys.argv[1], Path(sys.argv[2]), sys.argv[3]
    prove = tutte(cartella)
    if modo == "quante":
        print(len(prove))
        return 0
    pezzo, quanti = (int(parte) for parte in sys.argv[4].split("/"))
    scelte = mie(prove, pezzo, quanti)
    if not scelte:
        print("")
        return 0
    if modo == "filtro":
        dentro = "|".join(f"{c}/{p}" for c, p in scelte)
        print(f"^{re.escape(modulo)}\\.(?:{dentro})$")
    else:
        print(" ".join(f"-only-testing:{modulo}/{c}/{p}" for c, p in scelte))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
