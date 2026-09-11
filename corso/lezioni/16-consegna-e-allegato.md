# La consegna e l'allegato tecnico

<!-- parte: C · Chiudere | quando: 13:25 | durata: 60 minuti, con le domande teoriche | obiettivo: Hai l'archivio da consegnare, provato da scompattato, con l'allegato completo e le due risposte teoriche. -->

L'ultima ora non si scrive codice. Si prepara l'archivio, si completa
l'allegato e si risponde alle domande teoriche: sono 16 punti su 40, e si
prendono con la testa fredda.

## Un comando

```bash
task consegna NOME=ROSSI_MARIO
```

Prima controlla che il progetto sia coerente (`task check`) e si ferma se non
lo è. Poi prepara la cartella `consegna/`:

| File | Cos'è |
| :--- | :--- |
| `<modulo>/` | i sorgenti di ogni modulo, **senza** `target/` |
| `docker-compose.yml`, `Dockerfile`, `pom.xml`, `mvnw`, `.mvn/` | accanto ai moduli, come nel progetto: lo stack riparte dai sorgenti |
| `ALLEGATO-TECNICO.md` | l'allegato, con dentro quello che si ricava dal progetto e quello che hai scritto tu |
| `SCHEMA-DATABASE.md` | lo schema concettuale e logico, letto dal database |
| `ISTRUZIONI-ESECUZIONE.md` | come farlo partire, con Docker e senza |
| `ROSSI_MARIO.zip` | tutto quanto sopra in un archivio solo: **è quello da consegnare** |

Dentro l'archivio non ci sono altri archivi: chi corregge lo scompatta, entra
nella cartella con `docker-compose.yml` e lancia `docker compose up -d --build`.

## L'allegato: metà lo scrive il comando, metà tu

| Sezione | Chi la scrive |
| :--- | :--- |
| 1. Analisi del problema | tu, in `allegato.md` sotto `## Analisi` |
| 2. Architettura: moduli, porte, nomi su Eureka | il comando, dal progetto |
| 3. Schema concettuale e logico | il comando, dal database (come `task db-schema`) |
| 4. I moduli: endpoint esposti | il comando, dai controller |
| 4. I moduli: che cosa fa ognuno | tu, sotto `## <nome del modulo>` |
| 5. L'algoritmo | tu, sotto `## Algoritmo` |
| 6. Istruzioni per il collaudo | il comando |
| 7. Risposte alle domande teoriche | tu, se le vogliono qui: `## Domanda A`, `## Domanda B` |

Il tuo testo sta in `allegato.md`, nella cartella del progetto, e non dentro
`consegna/`, che a ogni giro si rifà da zero. La prima consegna crea il file
con tutti i titoli pronti (se non l'hai già scritto alla [lettura della
traccia](06-leggere-la-traccia.md)); le successive ne prendono ogni sezione e
la mettono al suo posto **prima** di fare l'archivio. Quindi l'archivio ha
sempre dentro l'ultima versione del testo, e puoi rilanciare la consegna
quante volte vuoi. Un modulo nato dopo l'ultima consegna trova la sua sezione
aggiunta in fondo al file.

Alla fine il comando ti dice che cosa manca:

```text
  ROSSI_MARIO.zip   41 KB   <- questo e' l'archivio da consegnare

  Nell'allegato mancano ancora: Algoritmo, biblioteca-ui.
  Scrivile in allegato.md, nella cartella del progetto, e rilancia
  task consegna: l'archivio si rifa' con dentro il testo.
```

Una sezione lasciata fra parentesi quadre conta come da scrivere. Per la
Biblioteca, `allegato.md` finito è così (l'algoritmo è quello della
[lezione 11](11-algoritmo.md)):

```markdown allegato.md
## Analisi

La biblioteca di quartiere informatizza catalogo e prestiti. Il bibliotecario
consulta i libri con autore, genere e disponibilita', registra un prestito
indicando l'email di chi prende il libro e la durata (30 giorni di norma, al
massimo 60), e registra la restituzione. Il sistema impedisce di prestare un
libro gia' fuori e calcola la penale per i ritardi.

## Algoritmo

Per ogni prestito si calcola il ritardo come il numero di giorni fra la data
di scadenza e la data di riferimento ...

## naming-server

Il registro Eureka: i servizi vi si registrano col loro nome e lo usano per
trovarsi, senza indirizzi scritti nel codice.

## catalogo-service

Tiene libri e autori su PostgreSQL (database biblioteca) e dice agli altri
servizi se un libro e' disponibile.

## prestiti-service

Registra prestiti e restituzioni su un database suo (prestiti), chiede i libri
al catalogo via Feign e calcola ritardo e penale.

## biblioteca-ui

L'interfaccia Thymeleaf: mostra catalogo e prestiti, registra un prestito con
un form validato e una restituzione con un bottone.
```

## Provala come la proverà chi corregge

Prima di consegnare, fai tu la stessa prova: scompatta `ROSSI_MARIO.zip` in una
cartella nuova, fuori dal progetto, e da lì

```bash
docker compose up -d --build
```

(Se lo stack del progetto è acceso, prima `task docker-down`: userebbe le
stesse porte.) Apri la pagina, fai un prestito, poi spegni con
`docker compose down -v`. Se parte da lì, parte anche sul PC della commissione.

## Le domande teoriche

Valgono 4 punti ciascuna, e si scrivono meglio se le leghi al tuo progetto: ne
hai appena costruito uno che risponde a metà delle domande.

**Domanda A — Docker, Compose, sicurezza.** Container e macchina virtuale: il
container condivide il kernel dell'host, parte in secondi, pesa megabyte, isola
meno; la VM ha un sistema operativo intero. Compose: il tuo
`docker-compose.yml` è l'esempio — servizi, rete comune in cui si chiamano per
nome, volume per i dati di PostgreSQL, healthcheck e `depends_on` per l'ordine
di avvio. Sicurezza e federazione: Spring Security nei servizi, un identity
provider come Keycloak che rilascia token OAuth2/OpenID Connect (JWT), un API
Gateway come unico ingresso che li verifica e li inoltra.

**Domanda B — Relazionale o NoSQL, Java EE o Spring Boot.** Un database
relazionale ha uno schema, le transazioni ACID e le join (i libri e i loro
autori); un NoSQL rinuncia a qualcosa di questo per scalare in orizzontale o
per dati senza schema fisso. Nella Biblioteca, lo storico delle letture o le
recensioni starebbero bene in MongoDB, la disponibilità in una cache Redis.
Java EE (Jakarta EE) gira in un application server e si configura a
descrittori; Spring Boot ha il server dentro il jar, gli starter e la
configurazione automatica, e con Spring Cloud dà Eureka e Feign.

Il testo completo, da adattare, sta nella Guida 2: [svolgimento delle domande
teoriche](../../guida_prova_finale_spring_boot.md#9-svolgimento-completo-delle-domande-teoriche-a-e-b).

> **Fatto quando**
>
> - [ ] `task consegna` finisce dicendo che l'allegato è completo
> - [ ] hai scompattato l'archivio altrove e `docker compose up -d --build` parte
> - [ ] nell'archivio non ci sono cartelle `target/` né altri archivi
> - [ ] le due domande teoriche hanno una risposta legata al tuo progetto
