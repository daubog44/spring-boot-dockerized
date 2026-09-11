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
ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    -Prep|--prep) PREP=1; shift ;;
    -All|--all) ALL=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

line() { printf '  %-26s%s\n' "$1" "$2"; }

# Le immagini che servono: quelle del Dockerfile piu' quella del compose.
IMAGES="$( { grep -E '^FROM[[:space:]]+' "$DEMO_DIR/Dockerfile" | awk '{print $2}'
             grep -E '^[[:space:]]+image:[[:space:]]*' "$DEMO_DIR/docker-compose.yml" | awk '{print $2}'
           } | sort -u )"

PROBLEMS=0

# Un progetto di prova, fuori dal tuo, con i moduli che new-service genera
# all'esame: un servizio REST con database e un'interfaccia web. Le loro
# dipendenze (JPA, H2, PostgreSQL, Feign, Swagger, Thymeleaf) nel progetto di
# oggi magari non ci sono ancora, e senza rete non si scaricherebbero piu'.
PROBE_MODULES="prova-offline-service,prova-offline-ui"
new_probe() {
  local probe deps
  probe="$(mktemp -d)"
  tar -cf - -C "$REPO_ROOT" \
    --exclude=target --exclude=.git --exclude=.dev-logs \
    --exclude=node_modules --exclude=.task --exclude=consegna . | tar -xf - -C "$probe"
  bash "$probe/scripts/new-service.sh" --name prova-offline-service >/dev/null 2>&1
  bash "$probe/scripts/new-service.sh" --name prova-offline-ui --ui >/dev/null 2>&1
  if [ "$ALL" = "1" ]; then
    deps="$(sed -n "s/^[[:space:]]*'\([a-z0-9-]*\)'[[:space:]]*=[[:space:]]*New-Dep.*/\1/p" "$probe/scripts/add-dep.ps1" | paste -sd, -)"
    bash "$probe/scripts/add-dep.sh" --module prova-offline-service --deps "$deps" >/dev/null 2>&1
  fi
  printf '%s\n' "$probe"
}

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

  # 1-bis. Le dipendenze dei moduli che creerai all'esame.
  echo ""
  echo "==> Dipendenze dei moduli che creerai (new-service, seed-data, db-schema)"
  [ "$ALL" = "1" ] && echo "  ... piu' tutto il catalogo di add-dep: ci vuole un po'."
  PROBE="$(new_probe)"
  # Con la fase dei test, anche se non ce ne sono: scarica il plugin che li esegue.
  if ( cd "$PROBE/demo" && ./mvnw -B -q dependency:go-offline && ./mvnw -B -q package -pl "$PROBE_MODULES" -am ); then
    line "moduli nuovi" "JPA, H2, PostgreSQL, Feign, Swagger, Thymeleaf scaricati"
  else
    line "moduli nuovi" "qualcosa non ha funzionato: guarda l'output sopra"
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

  # Anche dentro Docker: la build di un modulo nuovo scarica le sue dipendenze
  # nella cache di Maven delle build (--mount=type=cache nel Dockerfile), che
  # cosi' il giorno dell'esame le ha gia'. Le immagini di prova poi si tolgono.
  if ( cd "$PROBE/demo" && docker compose build prova-offline-service >/dev/null 2>&1 ); then
    line "build di un modulo nuovo" "fatta (cache Maven di Docker piena)"
  else
    line "build di un modulo nuovo" "fallita"
    PROBLEMS=$(( PROBLEMS + 1 ))
  fi
  ( cd "$PROBE/demo" && docker compose down --rmi local >/dev/null 2>&1 )
  rm -rf "$PROBE"

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

# 0. La rete di adesso: all'esame e' filtrata, e quello che passa oggi decide
#    che cosa deve essere gia' sul disco.
bash "$SCRIPT_DIR/rete.sh"

echo "E SE UN DOMINIO NON PASSA, C'E' GIA' TUTTO?"
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

# E un modulo nuovo, come quelli che creerai all'esame? Stessa prova, su un
# progetto usa-e-getta con un servizio con database e un'interfaccia.
echo "  Provo a compilare offline anche un modulo nuovo (servizio con database + interfaccia)..."
PROBE="$(new_probe)"
if ( cd "$PROBE/demo" && ./mvnw -B -q -o package -Dmaven.test.skip=true -pl "$PROBE_MODULES" -am >/dev/null 2>&1 ); then
  line "modulo nuovo offline" "RIESCE (new-service, seed-data, db-schema)"
else
  line "modulo nuovo offline" "FALLISCE: lancia task offline-prep con la rete"
  PROBLEMS=$(( PROBLEMS + 1 ))
fi
rm -rf "$PROBE"

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

# 4. L'editor. Anche lui scarica: l'estensione Java di Zed prende jdtls,
#    Lombok e il debugger al primo file .java che apri, e senza rete non puo'.
#    Il progetto parte lo stesso, quindi e' un avviso e non un problema.
echo ""
EDITOR_SEEN=0
ZED_ROOT=""
WIN_LOCAL=""
if [ -n "${LOCALAPPDATA:-}" ]; then
  if command -v cygpath >/dev/null 2>&1; then WIN_LOCAL="$(cygpath -u "$LOCALAPPDATA")"; else WIN_LOCAL="$LOCALAPPDATA"; fi
fi
for d in "$WIN_LOCAL/Zed" "$HOME/.local/share/zed" "$HOME/Library/Application Support/Zed"; do
  if [ -d "$d/extensions" ]; then ZED_ROOT="$d"; break; fi
done
if [ -n "$ZED_ROOT" ]; then
  EDITOR_SEEN=1
  ZJ="$ZED_ROOT/extensions/work/java"
  missing=""
  ls -d "$ZJ"/jdtls/jdt-language-server-* >/dev/null 2>&1 || missing="$missing jdtls"
  ls "$ZJ"/lombok/*.jar >/dev/null 2>&1 || missing="$missing Lombok"
  ls "$ZJ"/debugger/*.jar >/dev/null 2>&1 || missing="$missing debugger"
  if [ ! -d "$ZED_ROOT/extensions/installed/java" ]; then
    line "Zed (estensione Java)" "non installata: zed: extensions -> Java, con la rete"
  elif [ -n "$missing" ]; then
    line "Zed (estensione Java)" "manca$missing: apri un file .java in Zed, con la rete"
  else
    line "Zed (estensione Java)" "jdtls, Lombok e debugger gia' scaricati"
  fi
fi
if [ -d "$HOME/.vscode/extensions" ]; then
  EDITOR_SEEN=1
  if ls -d "$HOME"/.vscode/extensions/redhat.java-* >/dev/null 2>&1 &&
     ls -d "$HOME"/.vscode/extensions/vscjava.vscode-java-debug-* >/dev/null 2>&1; then
    line "VS Code (Java)" "estensioni Java e debugger installate"
  else
    line "VS Code (Java)" "manca l'Extension Pack for Java: installalo con la rete"
  fi
fi
[ "$EDITOR_SEEN" -eq 0 ] && line "editor" "ne' VS Code ne' Zed su questo PC"

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
