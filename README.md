# Spring Boot Multicanale - Docker Setup

Questo documento spiega come funziona la configurazione Docker di questo progetto e come sfruttarla al meglio.

## 🏗️ Come funziona il Build Multicanale (Multi-App)

Il progetto è progettato per gestire **molteplici esercizi/app in modo totalmente isolato**, pur risedendo nello stesso progetto.
Utilizza un **Dockerfile Multi-Stage**:
1. **Fase di Build**: Questa fase usa Maven per compilare ed estrarre **ESATTAMENTE ed ESCLUSIVAMENTE** il pacchetto Java che decidi tu. 
2. **Fase di Esecuzione**: Preleva soltanto l'eseguibile snello pulito e lo mette in una leggerissima immagine pronta all'uso.

Questo significa che se compili l'esercizio 1, il container Docker *non avrà letteralmente idea dell'esistenza* del codice dell'esercizio 2!

## 🚀 Come Eseguire i Container e Cambiare App

La magia avviene tutta passando il parametro `PKG` al tuo task. 
Di default, in cima al tuo file `Taskfile.yml` è definita una variabile globale `PKG: com.example.multicanalces`.

Se esegui semplicemente:
```bash
task run-docker
```
Lui compila e avvia in automatico l'esercizio `multicanalces`.

**Ma se vuoi avviare un altro esercizio, puoi sovrascrivere la variabile al volo!**
```bash
task run-docker PKG=com.example.bootlezione1
```
Facendo così:
1. Il `Taskfile` passerà il parametro `PKG` a `docker-compose`.
2. `docker-compose` passerà il parametro al `Dockerfile`.
3. Il `Dockerfile` re-impacchetterà l'app escludendo `multicanalces` e includendo solo `bootlezione1`.
4. Il tuo container verrà aggiornato e lanciato con la nuova applicazione.

_Nota tecnica:_ Il task effettua sempre due comandi: `docker compose up --build -d` (per forzare la ricompilazione se cambi PKG) seguito da `docker attach demo-multicanale` (per permettere alla console di leggere i tuoi input dello `Scanner`).

## ⚙️ Come Modificare la Configurazione (application.yml) senza Riavviare il codice

Tramite `docker-compose.yml` stiamo istruendo Spring Boot a sovrascrivere i valori del tuo `application.yml` interno usando variabili d'ambiente OS.

Questa è la "Best Practice" in ambito DevOps: **Il container (immagine) non deve mai cambiare. È la configurazione esterna a dictarne il comportamento.**

Nel `docker-compose.yml` vedrai:
```yaml
environment:
  - TTF_EMAIL_SMTP=smtp.docker.com
  - TTF_EMAIL_PORT=1025
...
```

Questi valori in maiuscolo seguono le regole di conversione automatica di Spring Boot:
* `TTF_EMAIL_SMTP` sovrascrive `ttf.email.smtp` nell'`application.yml`.
* `TTF_SMS_TOKEN` sovrascrive `ttf.sms.token`.

### Cambiare i valori in corsa
1. Apri `docker-compose.yml`.
2. Modifica a tuo piacimento i valori nel blocco `environment`.
3. Rilancia `task run-docker`. 

Poiché il codice Java non è cambiato, Docker capirà che c'è stato "solo" un aggiornamento di configurazione esterna: NON re-compilerà nulla, ma applicherà in una frazione di secondo i nuovi parametri al container in esecuzione!
