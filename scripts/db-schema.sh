#!/usr/bin/env bash
# Lo schema concettuale e logico della base dati, letto dal database vero.
# Equivalente POSIX di scripts/db-schema.ps1.
#
# Per ogni modulo con delle @Entity compila, avvia l'applicazione su un H2
# usa-e-getta, lascia che Hibernate crei le tabelle e le interroga con JDBC
# (il pacchetto devdata di common-dto). Il database del progetto non viene
# toccato.
#
#   task db-schema
#   task db-schema OUT=schema.md
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
. "$SCRIPT_DIR/scaffold-lib.sh"

OUT_FILE=""
BUILD=1
while [ $# -gt 0 ]; do
  case "$1" in
    -OutFile|--out) OUT_FILE="$2"; shift 2 ;;
    -NoBuild|--no-build) BUILD=0; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

TARGETS=()
while IFS= read -r row; do
  [ -n "$row" ] || continue
  rest="${row#*|}"
  [ "${rest%%|*}" = "1" ] && TARGETS+=("$row")
done < <(jpa_modules "$DEMO_DIR")

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DOC="$WORK/schema.md"
FAILED=0

{
  echo "# Schema concettuale e logico della base dati"
  echo ""
} >"$DOC"

if [ ${#TARGETS[@]} -eq 0 ]; then
  cat >>"$DOC" <<'EOF'
Nessuna classe `@Entity` trovata: il progetto non ha ancora persistenza.

Le entity si riconoscono cosi':

```java
@Entity
@Table(name = "ordini")
public class OrdineEntity { ... }
```

EOF
else
  cat >>"$DOC" <<'EOF'
Letto dal database vero: per ogni modulo con delle `@Entity` l'applicazione
e' stata avviata su un database vuoto, Hibernate ha creato le tabelle e
queste sono state interrogate con JDBC. Ogni microservizio ha il suo
database, quindi lo schema e' diviso per modulo.

EOF
  BUILD_OK=1
  if [ "$BUILD" = "1" ]; then
    LIST=""
    for row in "${TARGETS[@]}"; do LIST="${LIST:+$LIST,}${row%%|*}"; done
    echo "  db-schema: compilo con Maven..." >&2
    if ! build_modules "$DEMO_DIR" "$WORK/build.log" "$LIST"; then
      BUILD_OK=0
      echo "  La compilazione e' fallita:" >&2
      grep 'ERROR' "$WORK/build.log" | head -n 15 | sed 's/^/    /' >&2
    fi
  fi

  for row in "${TARGETS[@]}"; do
    name="${row%%|*}"
    h2="${row##*|}"
    printf '## Modulo `%s`\n\n' "$name" >>"$DOC"
    if [ "$BUILD_OK" = "0" ]; then
      printf '%s\n\n' '> Schema non letto: il progetto non compila. Sistema gli errori e rilancia `task db-schema`.' >>"$DOC"
      FAILED=$((FAILED + 1))
      continue
    fi
    echo "  db-schema: $name..." >&2
    fragment="$WORK/$name.md"
    devdata_run "$DEMO_DIR" "$name" "$h2" "$WORK/$name.log" "--dev-data.schema-out=$(native_path "$fragment")"
    code=$?
    if [ "$code" = "0" ] && [ -s "$fragment" ]; then
      if [ "$h2" != "1" ]; then
        printf '%s\n\n' "> Senza H2 fra le dipendenze lo schema e' stato letto dal database configurato del modulo." >>"$DOC"
      fi
      tr -d '\r' <"$fragment" >>"$DOC"
    else
      FAILED=$((FAILED + 1))
      printf '%s\n\n' "> Schema non letto: l'applicazione non e' partita. Rilancia \`task db-schema\` per i dettagli." >>"$DOC"
      echo "  $name: schema non letto" >&2
      devdata_report "$name" "$code" "$WORK/$name.log" >&2 || true
    fi
  done

  cat >>"$DOC" <<'EOF'
> Le tabelle le crea Hibernate all'avvio (`ddl-auto: update`) leggendo le
> classi `@Entity`: qui sono lette dal database dopo che le ha create, quindi
> nomi, tipi e vincoli sono quelli veri. Su PostgreSQL i tipi sono gli
> stessi; un enum salvato come stringa e' un VARCHAR con un CHECK sui valori.

EOF
fi

if [ -n "$OUT_FILE" ]; then
  cp "$DOC" "$OUT_FILE"
  echo "Schema scritto in $OUT_FILE"
else
  cat "$DOC"
fi
[ "$FAILED" -eq 0 ] || exit 1
