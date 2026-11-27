from __future__ import annotations

import json
import os
import sys
import urllib.request

POSTI_MAC = 5
PER_GLI_ALTRI = 1
MENO = 1


def _chiedi(via: str) -> dict:
    richiesta = urllib.request.Request(
        f"{os.environ['GITHUB_API_URL']}/repos/{os.environ['GITHUB_REPOSITORY']}/{via}",
        headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}",
                 "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(richiesta, timeout=20) as risposta:
        return json.load(risposta)


def occupati() -> int:
    questo = os.environ.get("GITHUB_RUN_ID", "")
    quanti = 0
    for stato in ("in_progress", "queued"):
        for corsa in _chiedi(f"actions/runs?status={stato}&per_page=30").get(
                "workflow_runs", []):
            if str(corsa.get("id")) == questo:
                continue
            lavori = _chiedi(f"actions/runs/{corsa['id']}/jobs?filter=latest&per_page=100")
            quanti += sum(1 for lavoro in lavori.get("jobs", [])
                          if lavoro.get("status") in ("in_progress", "queued")
                          and any("macos" in str(e) for e in lavoro.get("labels", [])))
    return quanti


def quanti_pezzi(liberi: int, prove: int) -> int:
    return max(MENO, min(max(MENO, prove), liberi - PER_GLI_ALTRI))


def main() -> int:
    prove = int(sys.argv[1]) if len(sys.argv) > 1 else POSTI_MAC
    try:
        liberi = POSTI_MAC - occupati()
    except Exception as guaio:
        print(f"non so quanti posti sono liberi ({guaio}): ne conto 3", file=sys.stderr)
        liberi = 3
    pezzi = quanti_pezzi(liberi, prove)
    print(f"posti Mac liberi {liberi}, prove {prove}: {pezzi} pezzi", file=sys.stderr)
    uscita = os.environ.get("GITHUB_OUTPUT")
    righe = f"quanti={pezzi}\npezzi={json.dumps(list(range(1, pezzi + 1)))}\n"
    if uscita:
        with open(uscita, "a", encoding="utf-8") as f:
            f.write(righe)
    else:
        print(righe, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
