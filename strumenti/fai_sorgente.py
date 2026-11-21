from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


PROGETTO = Path(__file__).resolve().parent.parent / "project.yml"
PERMESSO = re.compile(r"^\s+(NS\w+UsageDescription):\s*(.+?)\s*$")


def permessi(progetto: Path = PROGETTO) -> dict:
    trovati = {}
    for riga in progetto.read_text(encoding="utf-8").splitlines():
        preso = PERMESSO.match(riga)
        if preso:
            testo = preso.group(2)
            if len(testo) >= 2 and testo[0] == testo[-1] and testo[0] in "\"'":
                testo = testo[1:-1]
            trovati[preso.group(1)] = testo
    return trovati


def sorgente(versione: str, numero: str, minimo: str, ipa: Path, repo: str) -> dict:
    scarica = f"{repo}/releases/download/ultima"
    return {
        "name": "Visore",
        "identifier": "local.visore.sorgente",
        "apps": [{
            "name": "Visore",
            "bundleIdentifier": "local.visore.app",
            "developerName": "Officina",
            "localizedDescription": "Il tuo archivio di foto, cifrato, sull'iPhone.",
            "iconURL": f"{scarica}/icona.png",
            "appPermissions": {"entitlements": [], "privacy": permessi()},
            "versions": [{
                "version": versione,
                "buildVersion": numero,
                "date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "downloadURL": f"{scarica}/Visore.ipa",
                "size": ipa.stat().st_size,
                "minOSVersion": minimo,
            }],
        }],
        "news": [],
    }


if __name__ == "__main__":
    versione, numero, minimo, ipa, repo = sys.argv[1:6]
    print(json.dumps(sorgente(versione, numero, minimo, Path(ipa), repo), indent=2, ensure_ascii=False))
