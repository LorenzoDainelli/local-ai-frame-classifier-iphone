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
firma e lo mette nel rilascio «ultima». Dal PC Windows si installa con
SideStore o AltStore, che lo firmano con il tuo ID Apple.

## Dove sta il pacchetto

La prima volta si sceglie la cartella del pacchetto in File. Il Visore la
copia in una sua cartella privata, che non compare in File e non va nel
backup di iCloud, e da lì la legge. La cartella scelta resta ricordata: a
ogni apertura, se dentro c'è un pacchetto nuovo, il Visore lo ricopia da
solo. Se la cartella non c'è più, apre l'ultima copia.

## Face ID

La prima volta si scrive la password del forziere; poi l'app la tiene nel
Portachiavi dell'iPhone, protetta da Face ID o dal codice di sblocco, e la
chiede da sola all'apertura. Se la password non apre più il pacchetto, la
dimentica.
