# Il collaudo

<!-- parte: C · Chiudere | quando: 12:50 | durata: 20 minuti | obiettivo: Prima di chiamare la commissione hai provato ogni flusso della traccia, dai casi buoni agli errori, e sai dove guardare se uno non torna. -->

«Funziona» vuol dire che hai provato ogni cosa che la traccia chiede, compresi
i casi che devono dire di no. Venti minuti adesso valgono più di un'ora di
codice in più.

## Uno: il progetto è coerente

```bash
task check
```

Non avvia niente: legge i file e controlla che moduli, porte, Dockerfile,
compose e lista di avvio dicano la stessa cosa. Se hai toccato qualcosa a mano,
è qui che lo scopri.

## Due: i servizi si vedono fra loro

```bash
task status
```

Porta per porta chi è in ascolto, i container accesi e, soprattutto, chi è
registrato su Eureka. Un servizio acceso ma non registrato non lo chiama
nessuno.

## Tre: ogni flusso, anche quelli che dicono di no

Da Swagger (`http://localhost:8081/swagger-ui.html` e `:8082`) o dal browser:

| Prova | Come | Che cosa deve succedere |
| :--- | :--- | :--- |
| il catalogo ha dei libri | `GET :8081/api/libri` | 200 e i libri dei dati di prova |
| prestare un libro disponibile | `POST :8082/api/prestiti` con `libroId`, `utenteEmail`, `giorni` | 201; `GET :8081/api/libri/{id}` dice `disponibile: false` |
| prestarlo di nuovo | la stessa POST | 409 |
| un libro che non c'è | `libroId: 999` | 404 |
| un'email sbagliata | `utenteEmail: "non-una-email"` | 400 |
| restituirlo | `PUT :8082/api/prestiti/{id}/restituzione` | 200; il libro torna disponibile |
| restituirlo due volte | la stessa PUT | 409 |
| ritardo e penale | `GET :8082/api/prestiti` | i prestiti scaduti hanno `giorniRitardo` e `penale` |
| la pagina | `http://localhost:8090` | catalogo, prestiti, form; un prestito e una restituzione dalla pagina |
| un servizio giù | spegni il catalogo | i prestiti si vedono con «(libro N)», la pagina avvisa |

Nel branch `example/biblioteca` queste prove le fa uno script, dopo
`task dev` (o dopo `task docker-up`):

```bash
powershell -ExecutionPolicy Bypass -File test_e2e_biblioteca.ps1
```

Ogni riga dice che cosa ha provato e com'è andata; alla fine il conto. Per la
tua traccia, scriverne uno così è mezz'ora spesa bene: ti fa rifare tutte le
prove dopo ogni modifica, in dieci secondi.

## Quattro: l'algoritmo

```bash
./mvnw -pl prestiti-service -am test
```

(Dalla cartella `demo`; su Windows `.\mvnw.cmd`.) I test della penale,
raccontati nella [lezione sull'algoritmo](11-algoritmo.md).

## Se una prova non torna

Non fare ipotesi: guarda.

```bash
task logs SERVICE=prestiti
```

Con `show-sql: true` vedi anche le query. Un 500 ha sempre uno stack trace nel
log del servizio che l'ha dato: la prima riga `Caused by:` di solito dice
tutto. Un 404 su un endpoint che esiste è quasi sempre un percorso sbagliato,
nel controller o nel client Feign.

> **Fatto quando**
>
> - [ ] `task check` è pulito e `task status` mostra tutti i servizi su Eureka
> - [ ] hai provato ogni riga della tabella, errori compresi
> - [ ] i test dell'algoritmo passano
> - [ ] hai fatto dalla pagina un prestito e una restituzione, come li farai alla demo
