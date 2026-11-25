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

Il pacchetto arriva da solo dal computer col cavo, nella cartella privata del
Visore, che non va nel backup di iCloud. Mentre arriva, il Visore lo dice e
aspetta, e tiene lo schermo acceso finché la copia non è finita; quando ha
finito si apre con la password. Non c'è niente da scegliere.

Appena il pacchetto è arrivato intero, il Visore mette su ogni suo file la
protezione più forte di iOS: con l'iPhone bloccato i file non si leggono
nemmeno da lì. I file restano comunque cifrati con la password del forziere,
e la cartella non si vede nell'app File.

Se il pacchetto sta invece in File, sotto la password c'è «Il pacchetto è in
un'altra cartella». Il Visore la copia nella sua cartella privata e la
ricorda: a ogni apertura, se dentro c'è un pacchetto nuovo, lo ricopia da
solo. Se il pacchetto è arrivato col cavo, la cartella di File non conta più.

## Face ID

La prima volta si scrive la password del forziere; poi l'app la tiene nel
Portachiavi dell'iPhone, protetta da Face ID o dal codice di sblocco, e la
chiede da sola all'apertura. Se la password non apre più il pacchetto, la
dimentica.
