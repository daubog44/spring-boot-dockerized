# Documentazione Esame Spring Cloud — Biblioteca di quartiere

## Obiettivo

Questa soluzione informatizza catalogo e prestiti di una biblioteca di
quartiere: tre microservizi registrati su Eureka, due database PostgreSQL, una
penale per chi restituisce in ritardo e un'interfaccia web per il
bibliotecario. È la traccia che il corso del template (`task learn`) segue
lezione per lezione: ogni pezzo di codice mostrato nel corso sta qui.

## La traccia

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

## Architettura

| Modulo | Porta | Nome su Eureka | Database | Chiama |
| :--- | ---: | :--- | :--- | :--- |
| `naming-server` | 8761 | `eureka-server` | — | — |
| `catalogo-service` | 8081 | `CATALOGO-SERVICE` | PostgreSQL `biblioteca` | — |
| `prestiti-service` | 8082 | `PRESTITI-SERVICE` | PostgreSQL `prestiti` | `CATALOGO-SERVICE` |
| `biblioteca-ui` | 8090 | `BIBLIOTECA-UI` | — | `CATALOGO-SERVICE`, `PRESTITI-SERVICE` |

```
biblioteca-ui  --Feign-->  CATALOGO-SERVICE  -->  PostgreSQL "biblioteca"
      |
      +-------Feign-->  PRESTITI-SERVICE  -->  PostgreSQL "prestiti"
                              |
                              +--Feign-->  CATALOGO-SERVICE
```

In `common-dto` stanno i record che attraversano la rete: `LibroDto`,
`PrestitoDto` e `NuovoPrestitoRequest` (il corpo della POST, che la UI manda e
i prestiti ricevono). `PrestitoEntity` tiene solo `libroId`: la tabella dei
libri sta in un altro database, e una chiave esterna fra database non esiste.

Il progetto è stato montato con i comandi del template:

```bash
task db-config DBNAME=biblioteca USER=bib PASSWORD=bib2026
task new-service NAME=catalogo-service
task use-postgres SERVICE=catalogo-service
task new-service NAME=prestiti-service
task use-postgres SERVICE=prestiti-service DBNAME=prestiti
task new-service NAME=biblioteca-ui UI=1 PORT=8090
task add-dep SERVICE=prestiti-service DEPS=test
task seed-data
```

## Endpoint

| Metodo | Percorso | Servizio | Risponde |
| :--- | :--- | :--- | :--- |
| GET | `/api/libri` | catalogo | 200 |
| GET | `/api/libri/disponibili` | catalogo | 200 |
| GET | `/api/libri/{id}` | catalogo | 200, 404 |
| PUT | `/api/libri/{id}/disponibilita?disponibile=` | catalogo | 200, 404 |
| GET | `/api/prestiti` | prestiti | 200, con ritardo e penale a oggi |
| POST | `/api/prestiti` | prestiti | 201; 400; 404 libro inesistente; 409 già in prestito |
| PUT | `/api/prestiti/{id}/restituzione` | prestiti | 200; 404; 409 già chiuso |
| GET | `/` | biblioteca-ui | la pagina |
| POST | `/prestiti` | biblioteca-ui | il form del prestito, poi redirect |
| POST | `/prestiti/{id}/restituzione` | biblioteca-ui | il bottone della restituzione, poi redirect |

## L'algoritmo della penale

ritardo = max(0, giorni fra scadenza e riferimento), dove il riferimento è la
data di restituzione per un prestito chiuso e oggi per uno aperto;
penale = min(0,50 × ritardo; 20,00). Due funzioni pure in `PrestitoService`,
provate da `PenaleTest`:

```bash
cd demo && ./mvnw -pl prestiti-service -am test
```

## Avvio e collaudo

```bash
task dev
```

oppure, tutto in container, `task docker-up`. Poi:

```bash
powershell -ExecutionPolicy Bypass -File test_e2e_biblioteca.ps1
```

prova ogni flusso: Eureka e le health, il catalogo, un prestito (201), lo
stesso libro due volte (409), un libro inesistente (404), un'email sbagliata e
troppi giorni (400), la restituzione e la seconda restituzione (409), la penale
di ogni prestito con la formula della traccia, Swagger, e dalla pagina un form
sbagliato, un prestito e una restituzione.

| Indirizzo | Cosa |
| :--- | :--- |
| `http://localhost:8090` | l'interfaccia |
| `http://localhost:8761` | la dashboard Eureka |
| `http://localhost:8081/swagger-ui.html` | Swagger del catalogo |
| `http://localhost:8082/swagger-ui.html` | Swagger dei prestiti |

## Consegna

Le parti dell'allegato scritte a mano sono in `allegato.md`;
`task consegna NOME=COGNOME_NOME` le unisce a moduli, endpoint e schema del
database e prepara l'archivio.
