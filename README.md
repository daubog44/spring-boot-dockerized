# Spring Boot Dockerized — Template d'esame ITS

Template **vuoto** per una prova finale a microservizi: c'è l'impalcatura già
configurata e collaudata (Eureka, OpenFeign, OpenAPI/Swagger, PostgreSQL, Docker
Compose, hot reload), **non** c'è nessun servizio d'esempio da smontare.

I servizi della traccia li generi con un comando:

```bash
task new-service NAME=ordini-service
```

che crea il modulo *e* lo collega dove serve — pom aggregatore, Dockerfile,
docker-compose, lista di avvio — senza che tu debba ricordarti nessuno dei sei
posti.

---

## Documentazione

- **[Il giorno dell'esame: procedura operativa](./GIORNO-ESAME.md)** — le quattro fasi, dal clone alla demo. **Parti da qui.**
- [Guida 1: Setup & Cheat Sheet Emergenze](./guida_setup_e_cheatsheet.md)
- [Guida 2: Manuale Omnicomprensivo Prova Finale Spring Boot](./guida_prova_finale_spring_boot.md) — c'è anche **come funziona il tutto insieme**: il giro di una richiesta da browser a database, chi accende cosa (Lombok, Swagger, Feign, JPA/Hibernate) e come si usa `common-dto`
- [Guida 3: Multi-Modulo Maven e Funzionamento](./guida_multi_modulo_maven.md)

Dal terminale, la guida ai comandi è `task help` (o `task` da solo); il
dettaglio di un comando singolo, con le sue variabili, è
`task --summary <comando>`.

---

## Branch

- **`main`** (questo): il template vuoto. È da qui che si parte a ogni traccia.
- **[`solution/wms`](https://github.com/daubog44/spring-boot-dockerized/tree/solution/wms)**: soluzione completa della traccia **WMS magazzino** (product, crm, wms, wms-ui, calcolo distanza Manhattan, DTO condivisi, collaudo end-to-end).
- **[`example/tourist-events`](https://github.com/daubog44/spring-boot-dockerized/tree/example/tourist-events)**: esempio svolto della traccia **eventi/turismo** (wrapper OpenFeign di OpenDataHub, estrazione casuale, storico su PostgreSQL).

I due branch svolti servono da riferimento: non serve copiarli, serve
guardarli quando non ricordi come si fa una cosa.

---

## Cosa c'è nel template

Aggregatore Maven multi-modulo dentro `demo/`:

| Modulo | A cosa serve |
| :--- | :--- |
| `naming-server` | Eureka Server, porta `8761`. I servizi si registrano qui e si chiamano per nome. |
| `common-dto` | Le classi condivise fra i servizi (DTO). Un modulo solo, così non si duplicano. |

E, già pronto e configurato per i moduli che creerai:

- **Spring Boot 4.0.5** e **Spring Cloud 2025.1.1** con le versioni gestite dal pom padre: nei moduli le dipendenze si scrivono senza versione.
- **spring-boot-devtools** ereditato da tutti i moduli: hot reload dopo `task compile`.
- **springdoc-openapi**: ogni modulo creato da `task new-service` espone `/swagger-ui.html` dal primo avvio, senza configurazione (per gli altri c'è `task enable-swagger`).
- **PostgreSQL** in `docker-compose.yml` (database `esame`, utente e password `exam`): c'è un container, **non collegato a niente** finché non lo chiedi. I moduli generati partono con H2 in memoria; `task use-postgres SERVICE=<modulo>` sposta un modulo sul database vero, e con `DBNAME=` gliene dà uno tutto suo dentro lo stesso container.
- **Dockerfile unico** parametrico sul modulo: un'immagine per servizio, senza un Dockerfile per cartella.

---

## Come si lavora

Una volta sola, all'inizio:

```bash
task dev
```

Libera le porte, compila e avvia in background quello che c'è, con hot reload.
Restituisce il prompt: niente finestre sparse da inseguire.

Poi il ciclo della giornata:

> scrivi il codice → `task compile` → il servizio si riavvia da solo

I log di tutti i servizi, in un terminale solo:

```bash
task logs
```

Quando qualcosa non risponde, prima di formulare ipotesi:

```bash
task status
```

Dice porta per porta chi è in ascolto — un tuo servizio, i container, o
un'applicazione estranea — e cosa si è registrato su Eureka.

### Quando cambia la struttura

Aggiungere un modulo o una dipendenza, o spostare una porta, tocca più file che
devono restare d'accordo. Un comando per ognuna di queste cose:

```bash
task new-service NAME=ordini-service
```

```bash
task add-dep SERVICE=ordini-service DEPS=security,mail
```

```bash
task set-port SERVICE=ordini-service PORT=8090
```

```bash
task remove-service SERVICE=ordini-service
```

```bash
task use-postgres SERVICE=ordini-service
```

```bash
task enable-swagger SERVICE=ordini-service
```

Tutti si usano con variabili `NOME=valore`, mai con trattini. Dopo una
dipendenza o un modulo nuovo ci vuole `task dev`: `task compile` non basta,
perché il classpath di un servizio è fissato quando parte.

Due comandi di controllo:

```bash
task check
```

Verifica, senza avviare niente, che moduli, porte, Dockerfile, compose e liste
di avvio dicano la stessa cosa.

```bash
task test
```

Collauda gli strumenti stessi su una copia usa-e-getta del progetto. Lancialo
appena ti siedi: se passa, sai che funzionano quando ti serviranno.

### Per la demo

```bash
task docker-up
```

Lo stack in container, che è quello che presenterai. Non devi fermare niente
prima: `docker-up` spegne da solo lo stack locale, e `task dev` spegne da solo i
container. Alla fine `task docker-down` (i dati del database restano;
`docker-reset` invece li cancella).

---

## Porte

| Indirizzo | Cosa |
| :--- | :--- |
| `http://localhost:8761` | Dashboard Eureka |
| `localhost:5432` | PostgreSQL (db `esame`, utente `exam`, password `exam`) |
| `http://localhost:<porta>/swagger-ui.html` | Swagger di un servizio |

Le porte dei servizi che crei le assegna `task new-service` (la prima libera
dopo l'ultima usata) e le stampa `task dev` alla fine dell'avvio. Per cambiarne
una: `task set-port SERVICE=<modulo> PORT=<porta>`.

> Se su una porta gira un'applicazione che ti serve viva, dillo:
> `task dev KEEPFOREIGN=1 UI_PORT=9080`. Senza `KEEPFOREIGN=1` viene chiusa.

---

## 🩺 Troubleshooting

### `dependency failed to start: container exam-eureka is unhealthy`

Sintomo: `task docker-up` fallisce, `exam-eureka` risulta `unhealthy` e nessun microservizio parte, anche se nei log Eureka scrive regolarmente `Started Eureka Server`.

Causa: l'healthcheck di `eureka-server` invoca `curl` su `/actuator/health`, ma l'immagine runtime `eclipse-temurin:25-jre` **non include `curl`**. Ogni probe fallisce con `curl: not found`, il container resta `unhealthy` e tutti i servizi con `depends_on: condition: service_healthy` non vengono mai avviati.

Il `demo/Dockerfile` di questo repo installa già `curl` nello stage runtime, quindi il problema non si presenta. Se aggiungi un healthcheck HTTP a un altro servizio, ricordati che vale la stessa regola.

Per capire *perché* un healthcheck non passa, leggi l'output delle probe:

```bash
docker inspect exam-eureka --format "{{json .State.Health}}"
```

### Su `http://localhost:8080` risponde qualcos'altro

Sintomo: il browser mostra una pagina che non è la tua (`Method Not Allowed`, un errore di un altro server, una app che non c'entra), anche se i servizi risultano avviati.

Causa: un'altra applicazione della macchina è in ascolto su `127.0.0.1:8080`. Su Windows il bind più specifico vince su quello generico, quindi `http://localhost:8080` finisce a quel processo anche quando Docker pubblica la porta su `0.0.0.0`. Se invece è lo stack locale a dover partire, Tomcat non riesce nemmeno a fare il bind e il servizio muore con `Web server failed to start. Port 8080 was already in use`.

```bash
task status
```

Elenca ogni processo in ascolto sulle porte dello stack e segnala esplicitamente questo caso. `task dev` chiude da solo quel processo al prossimo avvio; se invece ti serve tenerlo vivo, sposta la UI con `task dev KEEPFOREIGN=1 UI_PORT=9080`.

### Altri controlli utili

```bash
docker compose ps
```

```bash
docker logs exam-eureka --tail 50
```

Per verificare quali servizi si sono effettivamente registrati su Eureka:

```bash
docker exec exam-eureka curl -s -H "Accept: application/json" http://localhost:8761/eureka/apps
```
