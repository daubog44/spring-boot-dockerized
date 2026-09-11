# Quando qualcosa va storto

<!-- parte: C · Chiudere | quando: sempre | durata: da tenere aperta | obiettivo: Per ogni sintomo sai qual è il primo comando da lanciare, invece di fare ipotesi. -->

La regola è una: **prima guarda, poi pensa.** Quasi ogni problema si capisce
in trenta secondi con due comandi.

```bash
task status
```

```bash
task logs SERVICE=<nome>
```

Il primo dice chi è acceso, su che porta, chi occupa le porte che ti servono e
chi è registrato su Eureka. Il secondo ti mostra che cosa ha detto il servizio
che non va, col nome breve che vedi nel primo (`catalogo`, `prestiti`,
`biblioteca-ui`).

## Sintomo, e che cosa fare

| Sintomo | Che cosa fare |
| :--- | :--- |
| un servizio non risponde | `task status`, poi `task logs SERVICE=<nome>` |
| *Port 8081 was already in use* | `task dev`: chiude lui chi tiene la porta |
| su `localhost:8080` risponde un'altra applicazione | `task dev` la chiude; se ti serve viva, `task dev KEEPFOREIGN=1 UI_PORT=9080` |
| hai cambiato il codice e non cambia niente | `task compile`, e leggi se ci sono errori di compilazione |
| hai aggiunto una dipendenza o un modulo e non si vede | `task dev`: il classpath si fissa all'avvio |
| hai cambiato l'`application.yml` e non cambia niente | `task dev`: la configurazione si legge all'avvio |
| *Load balancer does not contain an instance for the service X* | aspetta 10 secondi; poi confronta il nome in `@FeignClient` con la dashboard di Eureka |
| `FeignException$NotFound` su un endpoint che esiste | il percorso nel client Feign non è quello del controller |
| un 500 dalla pagina | `task logs SERVICE=biblioteca-ui`: di solito è un servizio chiamato che ha dato errore, e lo dice |
| *password authentication failed* o *database "prestiti" does not exist* | il volume di PostgreSQL è vecchio: `task docker-reset` (cancella i dati), poi `task dev` |
| *release version 25 not supported* | il JDK è più vecchio del progetto: `task set-java` |
| una porta **RISERVATA** in `task status` | l'ha presa Windows (Docker Desktop, Hyper-V): `task set-port` per spostare il servizio |
| `task docker-up` si ferma su *unhealthy* | `docker compose ps` e `docker compose logs <servizio>` dalla cartella `demo` |
| la build Docker non scarica le immagini | `task rete`: se Docker Hub non passa, servono quelle della sera prima (`task offline`) |
| Maven non scarica una dipendenza nuova | `task rete`: se Maven Central non passa, vale solo la `~/.m2` |
| `task` non è un comando riconosciuto | `. .\scripts\usa-task-locale.ps1` (o `source scripts/usa-task-locale.sh`): c'è già una copia in `.tools/task`, se hai lanciato `task offline-prep` la sera prima |
| è tutto ingarbugliato | `task dev-down`, poi `task dev` |

## Due comandi da non usare

> **Attenzione**
>
> **`task kill-java`** chiude *tutti* i processi Java della macchina: anche
> l'editor, e con lui il lavoro non salvato. Serve solo se il resto ha fallito.
>
> **`task docker-reset`** durante la demo cancella il database, dati di prova
> compresi. Per spegnere si usa `task docker-down`.

## Per saperne di più

Le guide del progetto hanno una sezione per le emergenze: [Se qualcosa va
storto](../../GIORNO-ESAME.md#se-qualcosa-va-storto) nella procedura del giorno
d'esame, e il [cheat sheet delle
emergenze](../../guida_setup_e_cheatsheet.md#5-cheat-sheet-risoluzione-emergenze-esame)
della Guida 1.

> **Fatto quando**
>
> - [ ] sai che il primo comando è sempre `task status`
> - [ ] sai la differenza fra `task compile` e `task dev`
> - [ ] sai perché `kill-java` e `docker-reset` non si usano alla leggera
