# Lo stile del Visore

Approvato dall'utente il 21 novembre 2026 (bozza A, versione 3.0.24): «semplicemente
impeccabile». Ogni cambio futuro al Visore segue questa linea. Se qualcosa qui non basta,
si fa una bozza, la si mostra all'utente e si aspetta che scelga.

## L'idea

- È lo stesso programma del fisso e del portatile, adattato al telefono: stessi colori,
  stesso carattere con le grazie, stessi tempi delle animazioni.
- Le foto sono il centro. Tutto il resto è sobrio, caldo e leggero. Niente fronzoli.
- Il tema segue l'iPhone (chiaro o scuro). Il Visore si usa in verticale e in orizzontale.
- La foto aperta si comporta esattamente come l'app Foto di iPhone. È la cosa più importante.

## I mattoni (tutti in `Visore/Stile.swift`)

Si usano sempre questi. Non si scrivono colori, caratteri o tempi a mano nelle schermate.

- **Colori `Tinta`**: gli stessi di `officina/web/statici/css/fondamenta.css`, chiaro e
  scuro. Accento arancio terracotta. `alone` (accento leggero) fa da sfondo alle icone.
  Sopra le foto si usano i colori fissi (`carta`, `arancio`) e il vetro scuro.
- **Carattere `Carattere`**: Source Serif 4 (licenza OFL, in `Visore/Caratteri`) per i
  titoli, le date e i nomi grandi. Il testo di sistema serve per le scritte piccole e i comandi.
- **Movimento `Moto`**: `gesto` 180 ms, `passo` 260 ms, `scena` 360 ms, sempre con la curva
  (.2,.8,.2,1). `molla` serve per i rimbalzi piccoli e `foglio` per i fogli dal basso.
- **Pezzi**:
  - `Testa`: il titolo grande serif, con «Indietro» sopra quando serve e i tasti tondi a destra.
  - `TestaCompatta`: la barra sottile che compare scorrendo.
  - `Tondo`: il tasto tondo 38 pt. Dentro un menu si usa `FacciaTondo`.
  - `Vetrino`: il tasto di vetro 44 pt sopra le foto. Dentro un menu si usa `FacciaVetrino`.
  - `Pillola`: per gli anni, i filtri e le scelte. Chi ha la × si toglie.
  - `Scheda` + `Riga` + `Separa`: le liste a carta. `Riga` ha l'icona, il nome su 2 righe
    al massimo, il sottotitolo, il numero e la freccia.
  - `Fila`: le pillole che vanno a capo. Una pillola troppo lunga si accorcia e non esce mai
    dal bordo.
  - `Annunci`/`AvvisoPillola`: il messaggino a pillola che sale dal basso e sparisce da solo
    dopo circa 2 s («Nei preferiti», «Aggiunte a …»).
  - `Vuoto`: la pagina vuota gentile, con icona, titolo serif e una riga di spiegazione.
  - `.foglioStile()`: i fogli dal basso, con angoli 26 e maniglia.
  - `.senzaBarraDiSistema()`: tutte le pagine usano la nostra testa, non la barra di iOS.
    Il dito da sinistra per tornare indietro resta attivo.

## Le schermate

- **Blocco**: il lucchetto, «Visore» grande in serif e la scadenza della firma. Il campo
  password è centrato e prende il bordo arancio quando è attivo. Il tasto Apri si riempie
  mentre controlla. Se la password è sbagliata o corta, il campo trema. In orizzontale le
  due metà stanno affiancate.
- **Barra in basso**: una pillola che galleggia, con solo **Foto, Nodi, Persone**. La macchia
  arancio scivola sulla sezione scelta. Toccare di nuovo la sezione in cui sei riporta alla
  prima pagina o in cima. Durante «Scegli» la barra sparisce.
- **In alto a destra**, in ogni pagina principale: la **lente (Cerca)** a sinistra
  dell'**ingranaggio (Impostazioni)**.
- **Foto**: il titolo serif con il conteggio. Sotto ci sono le pillole «Raccolte», «Tutte» e
  gli anni. I giorni hanno l'intestazione serif con i luoghi. Si pizzica per cambiare le
  colonne (1, 3, 5, 7): le colonne cambiano mentre pizzichi, con un'animazione e una piccola
  vibrazione. Non si ingrandisce mai tutta la pagina. In orizzontale le colonne aumentano. Le miniature compaiono
  sfumando, e tenendo premuto se ne vede l'anteprima. A destra c'è la barra per correre
  fra gli anni.
- **Foto aperta**, come l'app Foto di iPhone:
  - in alto: il vetrino Indietro, la data e l'ora in serif, il vetrino Informazioni;
  - in basso: la **striscia delle miniature** di prima e dopo, con quella attuale più larga,
    al centro. Toccarne una porta lì;
  - sotto la striscia: il cuore, togli dalla raccolta, aggiungi a una raccolta;
  - **un tocco** nasconde o rimostra tutto. Da nascosto lo sfondo diventa nero;
  - **tenendo premuto** la live photo si muove finché tieni. Compare la scritta LIVE, che
    diventa arancio mentre si muove;
  - due tocchi mettono il cuore grande;
  - giù di scatto chiude, su apre le informazioni;
  - si apre e si chiude con lo zoom dalla miniatura.
- **Informazioni**: un foglio a metà schermo. In cima giorno, ora e luogo, poi le carte e le
  pillole di persone e nodi, che vanno a capo.
- **Nodi**: sono righe a carta, non riquadri. Il nome **non deve mai sovrapporsi né uscire
  dalla carta**: sta su 2 righe al massimo, il numero non si stringe e il nome ha la
  precedenza. Dentro un nodo, le sottocategorie si mostrano a righe: le prime 4, poi
  «Mostra tutte». «Solo qui» e l'ordine stanno nel menu «…».
- **Persone**: righe con il volto tondo, il periodo e il conteggio. Dentro una persona c'è
  «Spesso insieme a» con i volti. Per due persone insieme i volti sono sovrapposti.
- **Cerca**: si apre a tutto schermo. In alto la ricerca a pillola, poi il tasto filtri e
  «Chiudi». Sotto ci sono le pillole dei filtri attivi con la ×, le ricerche recenti in una
  carta, gli anni e i filtri come pillole che vanno a capo. I risultati hanno prima le righe
  trovate (persone, nodi, luoghi, anni), poi la griglia.
- **Raccolte**: «Preferiti» in una carta a parte, poi le tue raccolte. Tenendo premuto si
  rinomina o si elimina.
- **Impostazioni**: un foglio con le carte a gruppi (Firma, Griglia, Blocco, Riservatezza,
  Foto aperta, Pacchetto, Licenze) e «Fine» in alto.
- **Giro di benvenuto**: l'icona in un quadrato arancio leggero, il titolo serif, i puntini
  che si allungano e il tasto pieno arancio.

## Regole fisse

- I testi sono in italiano semplice e corto. I nomi dei comandi nel giro e nelle impostazioni
  devono corrispondere ai gesti veri.
- Animazioni sempre: le cose compaiono sfumando o scivolando, mai di colpo. I tocchi
  importanti hanno la vibrazione leggera.
- Le pagine lasciano spazio sotto (circa 100 pt) per la barra che galleggia.
- Niente prove a misura di telefono per il programma del PC. Il Visore invece è per il
  telefono, verticale e orizzontale.
- Il compilatore è GitHub (macos-15-intel). Niente funzioni solo di iOS 26.
- La logica non si tocca per cambiare la grafica: sicurezza, scudo, diario, cassetto e
  pacchetto restano come sono.
