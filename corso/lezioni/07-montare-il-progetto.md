# Montare il progetto

<!-- parte: B · Svolgere la traccia | quando: 08:50 | durata: 15 minuti | obiettivo: I tre moduli della Biblioteca esistono, sono collegati a pom, Dockerfile, compose, avvio ed editor, e rispondono. -->

Deciso che cosa costruire, lo scheletro si monta in un quarto d'ora: nessun
file si scrive a mano.

## Con il wizard

```bash
task wizard
```

Per prima cosa allinea Java al JDK della macchina, poi fa le domande. Per la
Biblioteca:

| Domanda | Risposta |
| :--- | :--- |
| come si chiama la cartella dei moduli | Invio: resta `demo` |
| il pacchetto Java di base | Invio: resta `esame` |
| il progetto usa PostgreSQL? | sì: database `biblioteca`, utente `bib`, password `bib2026`, porta 5432 |
| primo servizio | `catalogo-service`: REST con database, porta proposta (8081), PostgreSQL condiviso |
| secondo servizio | `prestiti-service`: REST con database, porta proposta (8082), un database suo (`prestiti`) |
| terzo servizio | `biblioteca-ui`: interfaccia Thymeleaf, porta 8090 |
| quarto servizio | Invio per finire |

Alla fine lancia `task check`. Il wizard non fa niente di magico: chiama gli
stessi comandi che puoi dare a mano, nell'ordine giusto.

## Oppure, un comando alla volta

Sono i comandi con cui è stato montato il branch `example/biblioteca`:

```bash
task db-config DBNAME=biblioteca USER=bib PASSWORD=bib2026
task new-service NAME=catalogo-service
task use-postgres SERVICE=catalogo-service
task new-service NAME=prestiti-service
task use-postgres SERVICE=prestiti-service DBNAME=prestiti
task new-service NAME=biblioteca-ui UI=1 PORT=8090
task check
```

| Comando | Che cosa fa |
| :--- | :--- |
| `db-config` | nome, utente e password del PostgreSQL del compose, dappertutto |
| `new-service` | il modulo, e le righe in pom, Dockerfile, compose, lista di avvio ed editor |
| `use-postgres` | sposta un modulo da H2 in memoria al PostgreSQL del compose |
| `use-postgres ... DBNAME=` | come sopra, ma con un database tutto suo nello stesso container |
| `new-service ... UI=1` | un modulo Thymeleaf con un controller e una pagina |
| `check` | i sei posti dicono la stessa cosa? |

## Che cosa è cambiato

`git status` dopo quei comandi:

```text
 M .vscode/launch.json
 M .zed/debug.json
 M demo/Dockerfile
 M demo/docker-compose.yml
 M demo/pom.xml
 M scripts/dev.ps1
 M scripts/dev.sh
?? demo/biblioteca-ui/
?? demo/catalogo-service/
?? demo/postgres-init/
?? demo/prestiti-service/
```

Il blocco di `prestiti-service` nel compose, scritto da `new-service` e
completato da `use-postgres`:

```yaml demo/docker-compose.yml
  prestiti-service:
    build:
      context: .
      args:
        MODULE: prestiti-service
    environment:
      PRESTITI_DB_URL: jdbc:postgresql://postgres:5432/prestiti
      PRESTITI_DB_USERNAME: bib
      PRESTITI_DB_PASSWORD: bib2026
      PRESTITI_DB_DRIVER: org.postgresql.Driver
      SERVER_PORT: 8082
      EUREKA_SERVER_URL: http://eureka-server:8761/eureka/
    ports:
      - "8082:8082"
    depends_on:
      postgres:
        condition: service_healthy
      eureka-server:
        condition: service_healthy
```

E lo script che crea il secondo database, che PostgreSQL esegue la prima volta
che parte:

```sql demo/postgres-init/create-prestiti.sql
-- Creato da task use-postgres: un database per il modulo prestiti-service.
CREATE DATABASE prestiti;
GRANT ALL PRIVILEGES ON DATABASE prestiti TO bib;
```

> **Attenzione**
>
> PostgreSQL esegue gli script di `postgres-init/` e crea utente e database
> **solo quando il suo volume è vuoto**. Se il container era già partito prima
> di `db-config` o di `use-postgres ... DBNAME=`, serve una volta
> `task docker-reset`, che cancella i dati.

## Accendere tutto

```bash
task dev
```

Libera le porte, compila, avvia PostgreSQL in Docker, Eureka e poi i servizi,
in background. Alla fine stampa gli indirizzi. Per ora ogni servizio REST ha
solo l'endpoint di prova, che cancellerai quando scrivi il controller vero:

```bash
curl http://localhost:8081/api/ping
```

In un secondo terminale:

```bash
task logs SERVICE=catalogo
```

I nomi brevi (`eureka`, `catalogo`, `prestiti`, `biblioteca-ui`) sono quelli
che stampa `task status`. Da qui in poi il ciclo è: scrivi, `task compile`, il
servizio riparte da solo in qualche secondo.

## Se la traccia cambia a metà

| Serve | Comando |
| :--- | :--- |
| un servizio in più | `task wizard SERVICE=notifiche-service` |
| una libreria | `task add-dep SERVICE=prestiti-service DEPS=mail` |
| un'altra porta | `task set-port SERVICE=biblioteca-ui PORT=9090` |
| togliere un servizio | `task remove-service SERVICE=notifiche-service` |

Dopo un modulo o una dipendenza nuova ci vuole `task dev`, non
`task compile`: il classpath di un servizio si fissa quando parte.

> **Fatto quando**
>
> - [ ] `task check` dice *Tutto coerente*
> - [ ] `task dev` avvia tutto e `task status` mostra i tre servizi su Eureka
> - [ ] `http://localhost:8081/api/ping` risponde
> - [ ] sai quando serve `task docker-reset` e perché cancella i dati
