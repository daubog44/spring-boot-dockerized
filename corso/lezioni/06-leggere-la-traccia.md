# Leggere la traccia e disegnare i moduli

<!-- parte: B · Svolgere la traccia | quando: 08:30 | durata: 20 minuti | obiettivo: Dalla traccia della Biblioteca ricavi entità, servizi, porte, database, endpoint e algoritmo, e hai già scritto l'analisi che andrà nell'allegato. -->

I primi venti minuti non si scrive codice. Si legge la traccia con una matita
e si decide che cosa costruire: ogni minuto qui ne risparmia dieci dopo.

## La traccia

> **Biblioteca di quartiere**
>
> La biblioteca di quartiere vuole informatizzare il catalogo e i prestiti.
>
> 1. Il **catalogo** contiene i libri: titolo, codice ISBN di 13 cifre, anno
>    di pubblicazione, genere (romanzo, saggio, giallo, fantasy, storico),
>    autore (nome, cognome, nazionalità) e se il libro è disponibile.
> 2. Il servizio dei **prestiti** registra chi prende un libro (la sua email),
>    il giorno del prestito e la scadenza: di norma 30 giorni, al massimo 60.
>    Un libro già in prestito non si può prestare di nuovo.
> 3. Alla restituzione il libro torna disponibile. Per ogni giorno di ritardo
>    si paga una **penale** di 0,50 euro, fino a un massimo di 20 euro.
> 4. Un'**interfaccia web** mostra il catalogo e i prestiti, con il ritardo e
>    la penale, e permette di registrare un prestito e una restituzione.
> 5. I servizi si registrano su un **naming server Eureka** e si chiamano per
>    nome. Catalogo e prestiti hanno ognuno il proprio database PostgreSQL.
> 6. L'intero sistema parte con **Docker Compose**.
>
> Si consegnano i sorgenti, il `docker-compose.yml` e un allegato tecnico:
> analisi, schema del database, moduli e porte, l'algoritmo della penale,
> istruzioni per il collaudo. Seguono le domande teoriche A e B.

## Dal testo ai pezzi

Sottolinea i nomi (diventano dati), i verbi (diventano operazioni) e i
numeri (diventano regole):

| Nella traccia | Diventa |
| :--- | :--- |
| libri con titolo, ISBN, anno, genere, disponibilità | `LibroEntity` e l'enum `Genere`, in `catalogo-service` |
| l'autore con nome, cognome e nazionalità | `AutoreEntity`: molti libri, un autore |
| chi prende un libro, quando, la scadenza | `PrestitoEntity`, in `prestiti-service` |
| «30 giorni, al massimo 60» | un valore predefinito e `@Min(1) @Max(60)` sulla richiesta |
| «un libro già in prestito non si può prestare» | una regola nel service: si risponde **409 Conflict** |
| «alla restituzione torna disponibile» | `prestiti-service` avvisa il catalogo, via Feign |
| «0,50 euro al giorno, al massimo 20» | **l'algoritmo**: due funzioni e un test |
| un'interfaccia web | `biblioteca-ui`, con Thymeleaf |
| «ognuno il proprio database» | `task use-postgres`, con `DBNAME=prestiti` per il secondo |
| Eureka, Docker Compose | già nel template |

## Chi possiede quali dati

La regola dei microservizi è semplice: **ogni servizio possiede le sue
tabelle**, e gli altri gliele chiedono. Il catalogo possiede libri e autori;
i prestiti possiedono i prestiti.

Ne segue una cosa che all'inizio sembra strana: `PrestitoEntity` non ha una
relazione con `LibroEntity`, ma solo un `Long libroId`. Le due tabelle stanno
in due database diversi, e una chiave esterna fra database diversi non esiste.
La coerenza la tiene il codice: prima di prestare, `prestiti-service` chiede
il libro al catalogo; dopo, gli dice di segnarlo come non disponibile.

## Moduli, porte, database

| Modulo | Porta | Nome su Eureka | Database | Chiama |
| :--- | ---: | :--- | :--- | :--- |
| `naming-server` | 8761 | `eureka-server` | — | — |
| `catalogo-service` | 8081 | `CATALOGO-SERVICE` | PostgreSQL `biblioteca` | — |
| `prestiti-service` | 8082 | `PRESTITI-SERVICE` | PostgreSQL `prestiti` | `CATALOGO-SERVICE` |
| `biblioteca-ui` | 8090 | `BIBLIOTECA-UI` | — | `CATALOGO-SERVICE`, `PRESTITI-SERVICE` |

L'interfaccia va sulla 8090 e non sulla 8080: la 8080 è la prima porta che
trovi occupata da qualcos'altro. Un solo container PostgreSQL basta per tutti e
due i database.

## Gli endpoint

| Metodo | Percorso | Servizio | Risponde |
| :--- | :--- | :--- | :--- |
| GET | `/api/libri` | catalogo | 200 e l'elenco |
| GET | `/api/libri/disponibili` | catalogo | 200 e l'elenco |
| GET | `/api/libri/{id}` | catalogo | 200, 404 |
| PUT | `/api/libri/{id}/disponibilita?disponibile=false` | catalogo | 200, 404 |
| GET | `/api/prestiti` | prestiti | 200, con ritardo e penale calcolati a oggi |
| POST | `/api/prestiti` | prestiti | 201; 400 dati non validi; 404 libro inesistente; 409 già in prestito |
| PUT | `/api/prestiti/{id}/restituzione` | prestiti | 200; 404; 409 se è già chiuso |

Scriverli prima di cominciare vuol dire che i codici di risposta li decidi una
volta, e non a metà di un metodo.

## Scrivi subito l'analisi

L'allegato vale 8 punti, e metà si scrive adesso che la traccia è fresca. Le
parti che scrivi tu stanno in un file del progetto, `allegato.md`, diviso in
sezioni col titolo `##`:

```markdown allegato.md
## Analisi

La biblioteca di quartiere vuole informatizzare catalogo e prestiti: il
bibliotecario consulta i libri, registra chi ne prende uno e quando lo
riporta, e il sistema calcola la penale per i ritardi.

## Algoritmo

Per ogni prestito si calcola il ritardo come ...

## catalogo-service

Tiene i libri e gli autori, e dice agli altri se un libro e' disponibile.
```

- **Analisi**: il problema in cinque righe, che cosa fa il sistema e per chi;
- **Algoritmo**: la formula della penale, a parole e in simboli (la
  [lezione sull'algoritmo](11-algoritmo.md) ti dà il testo);
- **una sezione per modulo**, col nome del modulo come titolo: una o due righe
  su che cosa fa.

Se il file non c'è, lo crea la prima `task consegna` con tutti i titoli
pronti; puoi anche scriverlo tu adesso. Alla fine `task consegna` prende ogni
sezione e la mette al suo posto in `ALLEGATO-TECNICO.md`, accanto a moduli,
porte, endpoint e schema che ricava dal progetto. `task learn` lo mostra anche
dentro questo corso, fra le guide.

> **Prova tu**
>
> Fai la stessa analisi con la traccia del magazzino WMS (nella [Guida
> 2](../../guida_prova_finale_spring_boot.md), paragrafo 7): entità, servizi,
> chi possiede che cosa, l'algoritmo. Poi confrontala con la soluzione, nel
> branch `solution/wms`.

> **Fatto quando**
>
> - [ ] hai la tabella dei moduli con porte, nomi Eureka e database
> - [ ] hai la tabella degli endpoint con i codici di risposta
> - [ ] sai perché `PrestitoEntity` tiene solo `libroId`
> - [ ] l'analisi e la formula della penale sono scritte in un file
