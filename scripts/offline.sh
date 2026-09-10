#!/usr/bin/env bash
# Prepara e verifica il progetto per un esame senza rete.
# Equivalente POSIX di scripts/offline.ps1.
#
#   task offline-prep   (CON rete) scarica tutto quello che servira'
#   task offline        dice cosa c'e' e cosa manca
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"

PREP=0
while [ $# -gt 0 ]; do
  case "$1" in
    -Prep|--prep) PREP=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

line() { printf '  %-26s%s\n' "$1" "$2"; }

# Le immagini che servono: quelle del Dockerfile piu' quella del compose.
IMAGES="$( { grep -E '^FROM[[:space:]]+' "$DEMO_DIR/Dockerfile" | awk '{print $2}'
             grep -E '^[[:space:]]+image:[[:space:]]*' "$DEMO_DIR/docker-compose.yml" | awk '{print $2}'
           } | sort -u )"

PROBLEMS=0

if [ "$PREP" -eq 1 ]; then
  echo ""
  echo "PREPARAZIONE PER L'ESAME SENZA RETE"
  echo ""
  echo "  Serve internet ADESSO. Ci vogliono alcuni minuti."
  echo ""

  # 1. Le dipendenze Maven, nella cache di casa (~/.m2).
  echo "==> Dipendenze Maven"
  ( cd "$DEMO_DIR" && ./mvnw -B -q dependency:go-offline && ./mvnw -B -q clean package -Dmaven.test.skip=true )
  if [ $? -eq 0 ]; then
    line "maven" "scaricate e compilate"
  else
    line "maven" "qualcosa non ha funzionato: guarda l'output sopra"
    PROBLEMS=$(( PROBLEMS + 1 ))
  fi

  # 2. Le immagini di base, che Docker altrimenti va a prendere al volo.
  echo ""
  echo "==> Immagini Docker"
  for image in $IMAGES; do
    if docker pull "$image" >/dev/null 2>&1; then
      line "$image" "scaricata"
    else
      line "$image" "non scaricata"
      PROBLEMS=$(( PROBLEMS + 1 ))
    fi
  done

  # 3. La build dei container: riempie la cache dei livelli, compreso quello
  #    con curl (che a rete staccata non si potrebbe piu' installare).
  echo ""
  echo "==> Build delle immagini del progetto"
  if ( cd "$DEMO_DIR" && docker compose build ); then
    line "docker compose build" "fatta"
  else
    line "docker compose build" "fallita"
    PROBLEMS=$(( PROBLEMS + 1 ))
  fi

  echo ""
  if [ "$PROBLEMS" -eq 0 ]; then
    echo "Pronto: da adesso il progetto parte anche senza rete."
  else
    echo "Finito con $PROBLEMS problema/i: rileggi sopra."
  fi
  echo ""
  echo "  Verifica quando vuoi con: task offline"
  echo ""
  exit 0
fi

# --- Controllo ----------------------------------------------------------------

echo ""
echo "PRONTI PER UN ESAME SENZA RETE?"
echo ""

# 1. Gli attrezzi.
if command -v task >/dev/null 2>&1; then
  line "go-task" "$(task --version 2>/dev/null | head -n 1)"
else
  line "go-task" "non trovato"; PROBLEMS=$(( PROBLEMS + 1 ))
fi
if command -v java >/dev/null 2>&1; then
  line "JDK" "$(command -v java)"
else
  line "JDK" "non trovato"; PROBLEMS=$(( PROBLEMS + 1 ))
fi

# 2. La cache Maven: senza questa, offline non si compila.
M2="$HOME/.m2/repository"
if [ -d "$M2/org/springframework/boot" ]; then
  n="$(find "$M2/org/springframework/boot" -maxdepth 1 -type d | wc -l)"
  line "cache Maven (~/.m2)" "piena ($(( n - 1 )) artefatti Spring Boot)"
elif [ -d "$M2" ]; then
  line "cache Maven (~/.m2)" "c'e', ma senza Spring Boot"; PROBLEMS=$(( PROBLEMS + 1 ))
else
  line "cache Maven (~/.m2)" "non c'e'"; PROBLEMS=$(( PROBLEMS + 1 ))
fi

# La prova vera: compilare a rete finta staccata (-o = offline).
echo ""
echo "  Provo a compilare in modalita' offline..."
if ( cd "$DEMO_DIR" && ./mvnw -B -q -o clean package -Dmaven.test.skip=true >/dev/null 2>&1 ); then
  line "build offline (mvnw -o)" "RIESCE"
else
  line "build offline (mvnw -o)" "FALLISCE: lancia task offline-prep con la rete"
  PROBLEMS=$(( PROBLEMS + 1 ))
fi

# 3. Docker.
echo ""
if ! docker info >/dev/null 2>&1; then
  line "Docker" "non risponde (Docker Desktop e' acceso?)"
else
  LOCAL="$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null)"
  for image in $IMAGES; do
    # Le immagini tirate giu' da una build di buildx finiscono nella sua cache,
    # non nell'elenco locale: qui vogliamo proprio l'elenco locale, perche' e'
    # quello che sopravvive a tutto.
    if printf '%s\n' "$LOCAL" | grep -qx "$image"; then
      line "$image" "scaricata"
    else
      line "$image" "non scaricata: task offline-prep"
      PROBLEMS=$(( PROBLEMS + 1 ))
    fi
  done
fi

# --- Il verdetto --------------------------------------------------------------

echo ""
if [ "$PROBLEMS" -eq 0 ]; then
  echo "Tutto pronto: il progetto parte anche a rete staccata."
else
  echo "$PROBLEMS cosa/e da sistemare: lancia task offline-prep finche' hai rete."
fi
echo ""
echo "  Come presentare senza rete, in ordine di sicurezza:"
echo "    1. task dev      + task run-db   (Maven offline + il solo PostgreSQL in Docker)"
echo "    2. task docker-up                (tutto in container: rifa' le build, piu' fragile)"
echo ""
echo "  Il primo modo non ricompila niente dentro Docker: e' quello che regge"
echo "  meglio senza rete."
echo ""
[ "$PROBLEMS" -gt 0 ] && exit 1
exit 0
