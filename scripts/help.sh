#!/usr/bin/env bash
# Guida ai comandi: cosa lanciare, con quali variabili, in che ordine.
# Equivalente POSIX di scripts/help.ps1 — e' quello che stampa `task` da solo.
set -uo pipefail

cmd() { printf '  %-42s%s\n' "$1" "$2"; }
note() { printf '  %s\n' "$1"; }

cat <<'EOF'

COMANDI DEL PROGETTO
  Si usano con variabili NOME=valore, mai con trattini.
  Dettaglio di uno solo: task --summary <comando>

La giornata, in ordine
EOF
cmd "task dev" "compila e avvia tutto in background"
cmd "task logs" "segue i log (Ctrl+C esce, i servizi restano)"
cmd "task compile" "dopo una modifica al codice: si riavvia da solo"
cmd "task status" "chi occupa le porte, chi e' su Eureka"
cmd "task dev-down" "ferma tutto e libera le porte"

echo ""
echo "Modifiche strutturali (dopo queste ci vuole task dev)"
cmd "task add-dep SERVICE=<modulo> DEPS=<a,b>" "aggiunge dipendenze al pom"
cmd "task add-dep LIST=1" "i nomi brevi delle dipendenze"
cmd "task set-port SERVICE=<modulo> PORT=<n>" "sposta una porta, ovunque sia scritta"
cmd "task new-service NAME=<nome>" "crea un microservizio e lo collega"
cmd "task remove-service SERVICE=<modulo>" "lo toglie da tutto (l'inverso)"
note "new-service: UI=1 per un modulo Thymeleaf, NODB=1 senza database,"
note "PORT=<n> per sceglierla (di default la prima libera)."

echo ""
echo "Controlli"
cmd "task check" "moduli, porte, Docker e liste sono coerenti?"
cmd "task test" "collauda gli strumenti in una copia usa-e-getta"

echo ""
echo "Docker, per la demo"
cmd "task docker-up" "costruisce le immagini e avvia i container"
cmd "task docker-logs" "segue i log dei container"
cmd "task docker-down" "ferma i container, i dati restano"
cmd "task docker-reset" "ferma i container ED ELIMINA i dati"

echo ""
echo "Varianti utili"
cmd "task dev UI_PORT=9080" "la UI su un'altra porta, solo per stavolta"
cmd "task dev NOBUILD=1" "hai gia' compilato: solo riavvio"
cmd "task dev KEEPFOREIGN=1" "non chiudere le applicazioni estranee"
cmd "task logs SERVICE=<nome>" "un servizio solo"
cmd "task logs SERVICE=<nome> TAIL=200" "partendo da piu' indietro"

cat <<'EOF'

Se qualcosa va storto
  task status                chi tiene una porta
  task logs SERVICE=<nome>   le ultime righe del colpevole
  task dev                   rilanciabile quando vuoi: fa pulizia da solo
  GIORNO-ESAME.md            la procedura completa, passo per passo

  task --list   elenca tutti i comandi, anche quelli non citati qui.

EOF
