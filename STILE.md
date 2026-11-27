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
- **Vetro liquido** (`.vetro`, `GruppoDiVetro`, `Vetro`): acceso di base, come su iPhone, si
  spegne in Impostazioni › Aspetto con l'interruttore. Si usa solo per i comandi che
  galleggiano: tasti tondi, vetrini sopra le foto, barra in basso, barra della scelta,
  annunci, pillole sopra le foto, testa compatta (sfumata). È il vetro chiaro di iOS, il più
  trasparente. Nella foto aperta anche data e ora stanno in una pillola di vetro. Mai sul contenuto (righe, carte,
  pillole dei filtri). Spento, o con «Riduci trasparenza», o prima di iOS 26: tornano i pezzi
  pieni di prima. Il tasto A caso diventa vetro arancio. Tutto il vetro è **vivo** come il
  pallino delle barre di iOS 26: al tocco si gonfia, fa da lente e rimbalza.
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
  Finché non arriva il primo pacchetto vero, il Visore ricorda la prova con le foto finte e
  la apre con Face ID. Con il primo pacchetto vero la prova sparisce.
- **Barra in basso**: una pillola che galleggia, con solo **Foto, Nodi, Persone**. La macchia
  arancio scivola sulla sezione scelta. Toccare di nuovo la sezione in cui sei riporta alla
  prima pagina o in cima. Durante «Scegli» la barra sparisce.
- **In alto a destra**, in ogni pagina principale: la **lente (Cerca)** a sinistra
  dell'**ingranaggio (Impostazioni)**, e subito a destra il tasto **A caso**: tondo arancio
  pieno di 44 pt con le due frecce che si incrociano, 2 pt più staccato degli altri. È
  l'unico tasto colorato della testata. Il primo giorno ha un anello che pulsa piano.
- **A caso** (bozza A scelta): il tasto apre un foglio con il tipo di scatto (Foto, Live,
  Video: si accendono anche insieme, almeno uno resta acceso), i nodi (la freccia a sinistra
  apre i sotto-nodi, rientrati, e ognuno si sceglie da solo), le persone, gli anni,
  tre interruttori (prima i preferiti, audio dei video, ricomincia alla fine) e il ritmo
  (3, 5 o 8 secondi). In fondo il numero di scatti corre verso quello nuovo e il tasto
  «Mescola e guarda» parte. La mostra è nera, a tutto schermo, come le storie: barre in
  alto a gruppi di dieci, tocco a destra avanti, a sinistra indietro, al centro nasconde i
  comandi, tenere premuto ferma, due tocchi mettono il cuore, giù chiude. Le foto si muovono
  piano, i video e le Live partono da soli, l'audio sale piano.
- **Foto**, come l'app Foto di iPhone: lo scatto più nuovo è in basso a destra, quello prima
  alla sua sinistra, e così via; i più vecchi stanno sopra. La griglia si apre dal fondo, con
  gli ultimi scatti in vista, e salendo si torna indietro nel tempo. Non ci sono più
  intestazioni di giorni, mesi o anni: le foto stanno tutte attaccate, in una griglia sola.
  In cima restano fermi il titolo serif «Foto», sotto la data di quello che si vede e a destra
  i tasti (lente, ingranaggio, A caso); le foto scorrono sotto. Niente barra sfocata: solo una
  sfumatura leggera del colore del fondo (chiara o scura col tema) che sparisce verso il
  basso, perché le scritte si leggano. La data segue lo schermo e cambia con le cifre che
  scivolano: un giorno «12 Nov 2026», lo stesso mese «8–12 Nov 2026», due mesi
  «28 Ott – 3 Nov 2026», due anni «28 Dic 2025 – 3 Gen 2026»; a 15 per riga i mesi
  («Ott–Nov 2026»), a 31 gli anni («2025–2026»). Sotto la data ci sono il conteggio e le
  pillole «Raccolte», «Tutte» e gli anni: appena si sale di circa una riga spariscono sfumando,
  e tornano quando si è di nuovo in fondo. Si pizzica come in Foto di iPhone: 1, 3, 5 (di base),
  15 o 31 foto per riga. Mentre pizzichi non si ingrandisce mai la pagina: ogni foto si sposta
  e cambia misura un poco alla volta fra il suo posto di prima e quello del livello nuovo,
  seguendo le dita. La griglia non scorre e non trema; la foto sotto le dita resta sotto le
  dita, al passo di livello c'è una piccola vibrazione e, lasciate le dita, una molla finisce
  o annulla il passo. Ai bordi (1 e 31) l'elastico è duro. Le miniature diventano più nitide
  quando si ingrandiscono; a 1 per riga si vede la foto vera. In orizzontale le colonne
  aumentano (3, 7, 9, 25, 51). Le miniature compaiono sfumando, e tenendo premuto se ne vede
  l'anteprima. A destra c'è la barra per correre fra gli anni: in alto i più vecchi, in basso
  i più nuovi. Il modo di prima (dal più nuovo in alto, con le intestazioni dei giorni) resta
  nel codice: si riaccende con `Griglia.comeIPhone = false` in `Visore/GrigliaNativa.swift`.
  Le altre griglie (nodi, persone, raccolte, ricerca) restano come prima.
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
  - **video**: una sola riga di vetro, play/pausa a sinistra, la barra al centro, audio a
    destra. Il tempo non si vede. La barra è sottile, senza pallino, e scorre liscia (segue
    ogni fotogramma). Toccandola diventa un po' più spessa, i due tasti spariscono e sopra
    compaiono a sinistra il tempo passato «00:03,45» e a destra quello che manca «00:05»
    (arrotondato in su, senza meno). Il dito sposta in modo relativo, l'immagine segue il dito.
- **Informazioni**: un foglio a metà schermo. In cima giorno, ora e luogo, poi le carte e le
  pillole di persone e nodi, che vanno a capo.
- **Nodi** (bozza A scelta il 22 novembre 2026, con le righe della bozza B): righe a carta,
  non riquadri, con il **mosaico di 4 foto** (64 pt) che al tocco si apre e si inclina un poco.
  Sotto il nome: quante sottocategorie e il periodo. Il nome **non deve mai sovrapporsi né
  uscire dalla carta**: sta su 2 righe al massimo, il numero non si stringe e il nome ha la
  precedenza. Le righe entrano a cascata.
- **Dentro un nodo**: in cima tre foto grandi, poi la carta dei numeri (scatti nel ramo, solo
  qui, periodo). Le sottocategorie a righe: le prime 4, poi «Mostra tutte». Poi «Negli anni»
  a barre che crescono, «Dove» a pillole e le persone in fila. Toccare un anno o un luogo
  lascia nella griglia solo quelle foto e compare la pillola con la × per toglierlo.
  «Solo qui», l'ordine delle sottocategorie e quello delle foto stanno nel menu «…».
- **Persone**: in cima «Le più presenti», quattro volti con l'anello arancio che si riempie
  secondo quante foto hanno. Poi tutte dalla A alla Z, divise per lettera, con l'indice delle
  lettere a destra da toccare o strisciare. Al tocco il volto prende l'anello arancio.
- **Dentro una persona**: il volto grande che entra con una molla e fa un battito arancio,
  la carta dei numeri (la prima foto, l'anno con più, l'ultima), «Spesso insieme a» con i
  volti, «Negli anni», «Dove», «Nei nodi» e «Insieme, in due» con i volti sovrapposti.
  Anni e luoghi filtrano la griglia come nei nodi.
- **Cerca**: si apre a tutto schermo. In alto la ricerca a pillola, poi il tasto filtri e
  «Chiudi». Sotto ci sono le pillole dei filtri attivi con la ×, le ricerche recenti in una
  carta, gli anni e i filtri come pillole che vanno a capo. I risultati hanno prima le righe
  trovate (persone, nodi, luoghi, anni), poi la griglia.
- **Raccolte**: «Preferiti» in una carta a parte, poi le tue raccolte. Tenendo premuto si
  rinomina o si elimina.
- **Impostazioni**: foglio con la stessa grafica di «A caso»: titolo con riga sotto e tondo
  con la X, in cima due tessere (Vetro liquido, Proporzioni vere), poi le carte a gruppi
  (Firma, Blocco, Riservatezza, Foto aperta, A caso, Pacchetto, Licenze) che entrano una dopo
  l'altra, e in basso una barra di vetro col numero di scatti e «Rivedi il giro di benvenuto».
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
- Il compilatore è GitHub (macos-26 con Xcode 26). L'app parte da iOS 18: le funzioni di
  iOS 26 (il vetro) si usano solo con il ripiego per le versioni prima.
- La pillola e i tasti della testa non si schiacciano mai: è il titolo che si accorcia.
- La logica non si tocca per cambiare la grafica: sicurezza, scudo, diario, cassetto e
  pacchetto restano come sono.
