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

Dall'inizio alla consegna
EOF
cmd "task wizard" "fa le domande e monta il progetto"
cmd "task wizard SERVICE=<modulo>" "le domande di un microservizio solo"
cmd "task seed-data" "dati di prova dalle @Entity (data.sql)"
cmd "task db-schema" "schema concettuale e logico, dalle @Entity"
cmd "task consegna NOME=COGNOME_NOME" "la cartella da consegnare"
note "Il wizard e' anche task init. seed-data: SERVICE=<modulo>, ROWS=<n>."
note "db-schema: OUT=<file>. consegna genera l'allegato tecnico gia' compilato."

echo ""
echo "La giornata, in ordine"
cmd "task dev" "compila e avvia tutto in background"
cmd "task logs" "segue i log (Ctrl+C esce, i servizi restano)"
cmd "task compile" "dopo una modifica al codice: si riavvia da solo"
cmd "task status" "chi occupa le porte, chi e' su Eureka"
cmd "task dev-down" "ferma tutto e libera le porte"
cmd "task run SERVICE=<modulo>" "un modulo solo, in primo piano"

echo ""
echo "Modifiche strutturali (dopo queste ci vuole task dev)"
cmd "task add-dep SERVICE=<modulo> DEPS=<a,b>" "aggiunge dipendenze al pom"
cmd "task add-dep LIST=1" "i nomi brevi delle dipendenze"
cmd "task set-port SERVICE=<modulo> PORT=<n>" "sposta una porta, ovunque sia scritta"
cmd "task new-service NAME=<nome>" "crea un microservizio e lo collega"
cmd "task remove-service SERVICE=<modulo>" "lo toglie da tutto (l'inverso)"
cmd "task use-postgres SERVICE=<modulo>" "lo collega a PostgreSQL invece che a H2"
cmd "task enable-swagger SERVICE=<modulo>" "accende Swagger dove manca"
cmd "task db-config" "stampa credenziali e moduli collegati"
cmd "task db-config DBNAME=<db> USER=<u>" "le cambia dappertutto in una volta"
cmd "task rename-project NAME=<nome>" "rinomina la cartella dei moduli Maven"
cmd "task set-package PACKAGE=<base>" "cambia il pacchetto Java di tutti i moduli"
cmd "task set-java" "allinea Java al JDK di questa macchina"
note "new-service: UI=1 per un modulo Thymeleaf, NODB=1 senza database,"
note "PORT=<n> per sceglierla (di default la prima libera)."
note "use-postgres: DBNAME=<db> per dare al modulo un database tutto suo."
note "Swagger sui moduli nuovi c'e' gia': enable-swagger serve solo a rimetterlo."

cat <<'EOF'

  Le versioni delle dipendenze non si scrivono: le governa il pom.xml padre
  (Spring Boot piu' il BOM di Spring Cloud), quindi basta il nome. LIST=1
  stampa i 35 nomi brevi conosciuti (web, data-jpa, security, feign, kafka,
  postgresql...); se manca quello che ti serve, passa le coordinate:
  DEPS=org.apache.commons:commons-lang3:3.17.0
EOF

echo ""
echo "Controlli"
cmd "task check" "moduli, porte, Docker e liste sono coerenti?"
cmd "task test" "collauda gli strumenti in una copia usa-e-getta"
cmd "task ide-sync" "riallinea VS Code e Zed ai moduli veri"
note "ide-sync lo chiamano da soli new-service, remove-service e set-port."

echo ""
echo "Esame senza rete"
cmd "task offline-prep" "DA FARE CON LA RETE: scarica tutto"
cmd "task offline" "dice se partirebbe a rete staccata"
note "Senza rete presenta con task dev + task run-db: non ricompila dentro Docker."

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
