# Visore per iPhone

- `VisoreKit/`: il cuore, senza schermate. Apre il pacchetto fatto dal computer
  (stessa password del forziere), decifra i file a blocchi e legge `dati.db`.
- `Visore/`: l'app SwiftUI (sblocco, galleria, ricerca).
- `strumenti/fai_vettori.py`: rifà i file finti delle prove con il codice del
  computer. `prove/test_vettori_iphone.py` controlla che restino giusti.

Le prove Swift si fanno su un Mac con `swift test` dentro `VisoreKit/`.

## Deposito pubblico e costruzione

Questa cartella è pronta per diventare il deposito pubblico del Visore:
si copia così com'è nella radice del deposito nuovo. Il flusso
`.github/workflows/costruisci.yml` gira su un Mac di GitHub (gratis sui
depositi pubblici), fa le prove di VisoreKit, costruisce `Visore.ipa` senza
firma e lo mette nel rilascio «ultima» insieme a `sorgente.json`, la
sorgente per AltStore. Si installa con AltStore (AltServer sul fisso, regola
589): aggiunta la sorgente, le versioni nuove arrivano con un tocco.

## Face ID

La prima volta si scrive la password del forziere; poi l'app la tiene nel
Portachiavi dell'iPhone, aperta solo da Face ID. Si richiede scritta dopo
sette giorni, dopo un riavvio dell'iPhone e dopo cinque Face ID falliti
(regola 594). Il database del pacchetto si apre solo in memoria (regola 387).
Appena si esce dall'app, si richiude (regola 596).
