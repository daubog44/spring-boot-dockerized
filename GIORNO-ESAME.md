# Il giorno dell'esame — procedura operativa

Questa pagina è pensata per essere aperta e seguita, non ricordata. Se hai un
minuto solo, leggi le **quattro fasi** qui sotto e ignora il resto finché non
serve.

---

## Fase 0 — Prima di scrivere una riga di codice (10 minuti)

Fallo appena ti siedi, non quando ti serve.

```bash
git clone https://github.com/daubog44/spring-boot-dockerized.git
```

```bash
cd spring-boot-dockerized
```

Poi un giro a vuoto, che serve a scaricare dipendenze Maven e immagini Docker
**prima** di averne bisogno:

```bash
task dev
```

```bash
task dev-down
```

Se questi due comandi funzionano, il resto della giornata è in discesa. Se
falliscono, hai ancora tutto il tempo per capire perché.

> Le porte le libera `task dev` da solo, chiudendo quello che le tiene occupate:
> non devi controllare niente prima.

---

## Fase 1 — Sviluppo: il ciclo che ripeterai tutto il giorno

Una volta sola, all'inizio:

```bash
task dev
```

Compila tutto, avvia i servizi **in background** e ti restituisce il prompt.
Nessuna finestra sparsa da inseguire.

In un **secondo** terminale, se vuoi vedere cosa succede:

```bash
task logs
```

Ogni riga è prefissata dal nome del servizio e colorata. `Ctrl+C` chiude solo
questa vista: i servizi restano accesi. Per seguirne uno solo:
`task logs -- wms`.

Poi il ciclo è **solo questo**:

> scrivi il codice → `task compile` → il servizio si riavvia da solo in ~5 secondi

```bash
task compile
```

**Non rilanciare `task dev` a ogni modifica.** Ti serve solo quando cambi
qualcosa che un riavvio a caldo non copre: un `application.yml`, una porta, un
modulo nuovo nel `pom.xml`. Puoi lanciarlo quando vuoi, fa pulizia da solo.

Quando qualcosa non risponde, **prima di formulare ipotesi**:

```bash
task status
```

Ti dice, porta per porta, chi è in ascolto: un tuo servizio, i container, o
un'applicazione estranea. E cosa si è registrato su Eureka.

---

## Fase 2 — Collaudo, prima di chiamare la commissione

```bash
task test-e2e
```

Si può lanciare a stack acceso: se ne accorge, compila senza `clean` e aspetta
che i servizi si siano riavviati prima di interrogarli.

---

## Fase 3 — La demo

Non devi fermare niente prima: `task docker-up` spegne da solo lo stack locale.

```bash
task docker-up
```

Aspetta che `task status` mostri i quattro servizi registrati su Eureka, poi
apri nell'ordine:

1. `http://localhost:8080` — l'applicazione
2. `http://localhost:8761` — la dashboard Eureka, per far vedere il discovery
3. `http://localhost:8081/swagger-ui.html` — i contratti OpenAPI

Se ti chiedono della **resilienza**, spegni un servizio davanti a loro e
ricarica la dashboard: resta in piedi con i segnaposto invece di andare in
errore.

```bash
docker stop exam-crm-service
```

Alla fine:

```bash
task docker-down
```

---

## Se qualcosa va storto

| Sintomo | Cosa fare |
| :--- | :--- |
| Un servizio non risponde | `task status`, poi `task logs -- <servizio>` |
| "Port N was already in use" | `task dev`: chiude lui chi tiene la porta |
| Su `localhost:8080` risponde un'altra app | `task dev` la chiude; se ti serve viva, `task dev -- -KeepForeign -UiPort 9080` |
| Hai modificato il codice e non cambia niente | `task compile` (e controlla che non ci siano errori di compilazione) |
| Il servizio è morto dopo una modifica | `task logs -- <servizio>`, poi `task dev` per ripartire pulito |
| I container non partono | `task docker-down`, poi `task docker-up` |
| Il database ha dati sporchi | `task docker-reset`, poi `task docker-up` — **cancella i dati** |
| È tutto ingarbugliato | `task dev-down`, poi `task dev`. **Non** `task kill-java`: chiude anche l'IDE |

**L'unica trappola vera**: `task docker-reset` cancella il database,
`task docker-down` no. Durante la demo usa sempre `docker-down`.

---

## Tutti i comandi

`task` da solo stampa questo elenco con le descrizioni.

| Comando | Cosa fa |
| :--- | :--- |
| `task dev` | Libera le porte, compila e avvia tutto in background con hot reload |
| `task logs` | Segue i log di tutti i servizi in un terminale solo |
| `task compile` | Ricompila: i servizi toccati si riavviano da soli |
| `task status` | Chi occupa le porte, container attivi, registro Eureka |
| `task dev-down` | Ferma i servizi locali e libera le porte |
| `task test-e2e` | Collaudo end-to-end sui servizi accesi |
| `task docker-up` | Costruisce le immagini e avvia lo stack in container |
| `task docker-down` | Ferma i container, **conservando** i dati del database |
| `task docker-reset` | Ferma i container **ed elimina** i volumi |
| `task docker-logs` | Segue i log dei container |
| `task build` | Compila e impacchetta tutti i moduli Maven |
| `task run-eureka` · `run-product` · `run-crm` · `run-wms` · `run-wms-ui` | Avvia un solo modulo, in primo piano |
| `task kill-java` | Ultima spiaggia: termina **tutti** i java della macchina |

### Opzioni utili

| Opzione | Quando |
| :--- | :--- |
| `task dev -- -UiPort 9080` | Vuoi la UI su un'altra porta |
| `task dev -- -NoBuild` | Hai già compilato e vuoi solo riavviare |
| `task dev -- -KeepForeign` | Su una porta gira qualcosa che ti serve viva: non chiuderla |
| `task test-e2e -- -UiPort 9080` | Hai spostato la UI: dillo anche al collaudo |
| `task logs -- wms` | Un servizio solo |

---

## Cosa fa `task dev` all'avvio, in dettaglio

Serve saperlo solo se qualcosa va storto:

1. **Libera le porte** dello stack: ferma i suoi servizi di un avvio
   precedente, spegne i container dell'esame se sono loro a tenerle
   (`docker compose down`, i dati restano) e chiude le applicazioni estranee
   rimaste in ascolto. Non tocca mai i processi di sistema né l'infrastruttura
   di Docker: quelli te li segnala soltanto.
2. Cancella i log del giro precedente, così `task logs` non ti mostra roba
   vecchia.
3. Compila tutti i moduli, una volta sola.
4. Avvia Eureka e **aspetta** che sia in ascolto, poi tutti gli altri.
5. Se qualcosa non parte, stampa le ultime righe del log del colpevole e
   **ritira quello che aveva avviato**, invece di lasciare mezzo stack acceso.
