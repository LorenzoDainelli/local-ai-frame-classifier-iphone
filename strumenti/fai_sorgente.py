from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


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
