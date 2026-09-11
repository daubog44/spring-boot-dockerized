#!/usr/bin/env bash
# Cambia il pacchetto Java di base di tutti i moduli: sposta le cartelle dei
# sorgenti e riscrive package, import e mainClass.
# Equivalente POSIX di scripts/set-package.ps1.
#
# Riscrive solo "<base>.<sottopacchetto che esiste davvero>": una frase come
# "Buon esame." dentro una stringa resta com'e'. Il groupId Maven non cambia.
#
#   task set-package                     stampa quello attuale
#   task set-package PACKAGE=it.rossi
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
. "$SCRIPT_DIR/scaffold-lib.sh"

PACKAGE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -Package|--package) PACKAGE="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

CURRENT="$(base_package "$DEMO_DIR")"

if [ -z "$PACKAGE" ]; then
  echo ""
  echo "Il pacchetto di base e' '$CURRENT': i sorgenti stanno in src/main/java/$(printf '%s' "$CURRENT" | tr '.' '/')/<modulo>/."
  echo ""
  echo "  task set-package PACKAGE=<nuovo>     es. PACKAGE=it.rossi"
  echo ""
  exit 0
fi

if ! printf '%s' "$PACKAGE" | grep -qE '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$'; then
  echo "Pacchetto non valido: '$PACKAGE'. Parole minuscole separate da punti, ognuna comincia con una lettera: esame, it.rossi." >&2
  exit 1
fi
KEYWORDS=" abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while true false null record var yield "
for segment in $(printf '%s' "$PACKAGE" | tr '.' ' '); do
  case "$KEYWORDS" in
    *" $segment "*) echo "Pacchetto non valido: '$segment' e' una parola riservata di Java." >&2; exit 1 ;;
  esac
done
if [ "$PACKAGE" = "$CURRENT" ]; then
  echo ""
  echo "Il pacchetto di base e' gia' '$PACKAGE': non c'e' niente da fare."
  echo ""
  exit 0
fi

OLD_PATH="$(printf '%s' "$CURRENT" | tr '.' '/')"
NEW_PATH="$(printf '%s' "$PACKAGE" | tr '.' '/')"

echo ""
echo "==> $CURRENT -> $PACKAGE"
echo ""

# --- 1. Dove sono i sorgenti, e con quali sottopacchetti ---------------------
# Si riscrivono solo questi: "esame.ordiniservice" si', "esame.pdf" no.

ROOTS=""
SUBS=""
for module in "$DEMO_DIR"/*/; do
  [ -f "$module/pom.xml" ] || continue
  for kind in src/main/java src/test/java; do
    root="${module%/}/$kind"
    [ -d "$root/$OLD_PATH" ] || continue
    ROOTS="$ROOTS$root"$'\n'
    for sub in "$root/$OLD_PATH"/*/; do
      [ -d "$sub" ] && SUBS="$SUBS $(basename "$sub")"
    done
  done
done
SUBS="$(printf '%s\n' $SUBS | sort -u | tr '\n' '|' | sed 's/^|//; s/|$//')"
if [ -z "$SUBS" ]; then
  echo "Non trovo sorgenti in src/main/java/$OLD_PATH/: il pacchetto di base e' davvero '$CURRENT'?" >&2
  exit 1
fi

# --- 2. Le cartelle -------------------------------------------------------------
# Prima in una cartella d'appoggio, poi al posto nuovo: cosi' funziona anche
# quando la base nuova sta dentro la vecchia (esame -> esame.pro) o viceversa.

while IFS= read -r root; do
  [ -n "$root" ] || continue
  temp="$root/.set-package-$$"
  mv "$root/$OLD_PATH" "$temp"
  # Le cartelle rimaste vuote risalendo verso src/main/java (com/example/...).
  parent="$(dirname "$root/$OLD_PATH")"
  while [ "$parent" != "$root" ] && [ -d "$parent" ] && [ -z "$(ls -A "$parent")" ]; do
    rmdir "$parent"
    parent="$(dirname "$parent")"
  done
  if [ -d "$root/$NEW_PATH" ]; then
    mv "$temp"/* "$root/$NEW_PATH"/
    rmdir "$temp"
  else
    mkdir -p "$(dirname "$root/$NEW_PATH")"
    mv "$temp" "$root/$NEW_PATH"
  fi
  echo "  ${root#$DEMO_DIR/}/$NEW_PATH/"
done <<<"$ROOTS"

# --- 3. Il testo: package, import, mainClass, configurazione ------------------

OLD_RE="$(printf '%s' "$CURRENT" | sed 's/\./\\./g')"
MATCH="(^|[^A-Za-z0-9_])$OLD_RE\.($SUBS)([^A-Za-z0-9_]|\$)"
TOUCHED=0
while IFS= read -r file; do
  grep -qE "$MATCH" "$file" || continue
  # Due passate: in "a.x,a.y" la prima consuma la virgola che serve alla seconda.
  sed -i.bak -E -e "s/$MATCH/\1$PACKAGE.\2\3/g" -e "s/$MATCH/\1$PACKAGE.\2\3/g" "$file"
  rm -f "$file.bak"
  TOUCHED=$((TOUCHED + 1))
done < <(find "$DEMO_DIR" -mindepth 2 -name target -prune -o -type f \
  \( -name '*.java' -o -name pom.xml -o -name '*.yml' -o -name '*.yaml' -o -name '*.properties' \) -print)
echo "  $TOUCHED file riscritti (package, import, mainClass, configurazione)"

# --- 4. Gli editor, e la prova del nove ---------------------------------------

bash "$SCRIPT_DIR/ide-sync.sh" >/dev/null 2>&1
echo "  VS Code e Zed riallineati (la classe Main di ogni servizio)"

bash "$SCRIPT_DIR/check.sh" --project-only || {
  echo "task check ha trovato qualcosa: guarda sopra."
  exit 1
}

echo "  I moduli nuovi nasceranno in src/main/java/$NEW_PATH/<modulo>/."
echo "  task build          compila da capo e toglie le classi col pacchetto vecchio"
echo ""
