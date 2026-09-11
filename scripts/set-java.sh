#!/usr/bin/env bash
# Allinea il progetto a una versione di Java: di default quella del JDK
# installato su questa macchina. Equivalente POSIX di scripts/set-java.ps1.
#
# La versione e' scritta in quattro posti: <java.version> del pom, le immagini
# eclipse-temurin del Dockerfile, il runtime di VS Code e il JDK di ripiego del
# Taskfile. Spring Boot 4 vuole almeno Java 17.
#
#   task set-java
#   task set-java VERSION=21
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
. "$SCRIPT_DIR/scaffold-lib.sh"

MINIMUM=17
# La versione piu' nuova con cui il template e' stato provato.
TESTED=25

VERSION=""
while [ $# -gt 0 ]; do
  case "$1" in
    -Version|--version) VERSION="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

JDK="$(machine_jdk || true)"
JDK_VERSION=""
JDK_HOME=""
if [ -n "$JDK" ]; then
  JDK_VERSION="${JDK%%|*}"
  JDK_HOME="${JDK#*|}"
fi

if [ -z "$VERSION" ]; then
  if [ -z "$JDK" ]; then
    echo "Non trovo un JDK (ne' in JAVA_HOME ne' nel PATH). Installane uno da $MINIMUM in su, oppure indica la versione: task set-java VERSION=25" >&2
    exit 1
  fi
  VERSION="$JDK_VERSION"
fi
case "$VERSION" in
  ''|*[!0-9]*) echo "Versione non valida: '$VERSION'. Un numero: 17, 21, 25..." >&2; exit 1 ;;
esac
if [ "$VERSION" -lt "$MINIMUM" ]; then
  echo "Spring Boot 4 vuole almeno Java $MINIMUM: con Java $VERSION non parte. Installa un JDK piu' recente." >&2
  exit 1
fi
# Il percorso del JDK si scrive solo se e' davvero quella versione.
SAME_AS_MACHINE=0
[ "$JDK_VERSION" = "$VERSION" ] && SAME_AS_MACHINE=1

CURRENT="$(project_java_version "$DEMO_DIR")"

echo ""
echo "==> Java ${CURRENT:-?} -> $VERSION"
[ -n "$JDK" ] && echo "  JDK di questa macchina: Java $JDK_VERSION in $JDK_HOME"
echo ""

# --- 1. Il pom: con questa versione compila Maven ----------------------------

if ! grep -q '<java.version>' "$DEMO_DIR/pom.xml"; then
  echo "Non trovo <java.version> in demo/pom.xml: aggiungilo nelle <properties>." >&2
  exit 1
fi
sed -i.bak -E "s#<java\.version>[0-9]+</java\.version>#<java.version>$VERSION</java.version>#" "$DEMO_DIR/pom.xml"
rm -f "$DEMO_DIR/pom.xml.bak"
echo "  demo/pom.xml               <java.version>"

# --- 2. Il Dockerfile: il JDK che compila e il JRE che esegue -----------------

sed -i.bak -E "s#eclipse-temurin:[0-9]+-(jdk|jre)#eclipse-temurin:$VERSION-\1#g" "$DEMO_DIR/Dockerfile"
rm -f "$DEMO_DIR/Dockerfile.bak"
echo "  demo/Dockerfile            eclipse-temurin:$VERSION-jdk e -jre"

# --- 3. VS Code ---------------------------------------------------------------

SETTINGS="$REPO_ROOT/.vscode/settings.json"
if [ -f "$SETTINGS" ] && grep -q '"JavaSE-' "$SETTINGS"; then
  sed -i.bak -E "s#\"JavaSE-[0-9]+\"#\"JavaSE-$VERSION\"#" "$SETTINGS"
  if [ "$SAME_AS_MACHINE" -eq 1 ]; then
    # Il "path" del blocco dei runtime, che e' l'unico del file.
    sed -i.bak -E "/java\.configuration\.runtimes/,/\]/ s#(\"path\":[[:space:]]*\")[^\"]*(\")#\1$JDK_HOME\2#" "$SETTINGS"
  fi
  rm -f "$SETTINGS.bak"
  echo "  .vscode/settings.json      runtime JavaSE-$VERSION"
fi

# --- 4. Il JDK di ripiego del Taskfile ---------------------------------------

if [ "$SAME_AS_MACHINE" -eq 1 ]; then
  sed -i.bak -E "s#(for d in \"\\\$JAVA_HOME\" \")[^\"]*(\")#\1$JDK_HOME\2#" "$REPO_ROOT/Taskfile.yml"
  rm -f "$REPO_ROOT/Taskfile.yml.bak"
  echo "  Taskfile.yml               JDK di ripiego: $JDK_HOME"
fi

# --- Cosa resta da sapere -----------------------------------------------------

echo ""
echo "Java $VERSION."
if [ -n "$JDK_VERSION" ] && [ "$JDK_VERSION" -lt "$VERSION" ]; then
  echo ""
  echo "  Il JDK di questa macchina e' Java $JDK_VERSION: Maven non puo' compilare per Java $VERSION."
  echo "  In Docker funziona lo stesso (l'immagine ha il suo JDK); per task dev installa Java $VERSION."
fi
if [ "$VERSION" -gt "$TESTED" ]; then
  echo ""
  echo "  Spring Boot 4.0.5 e' stato provato fino a Java $TESTED: se qualcosa non parte, prova con $TESTED."
fi
if [ "${CURRENT:-}" != "$VERSION" ]; then
  echo ""
  echo "  Sono cambiate le immagini Docker di base: con la rete, task offline-prep"
  echo "  le scarica per l'esame senza rete."
fi
echo ""
echo "  task build          per vedere che compila"
echo ""
