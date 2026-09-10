#!/usr/bin/env bash
# Ricava lo schema del database dalle @Entity del progetto.
# Equivalente POSIX di scripts/db-schema.ps1: legge i sorgenti, non si collega
# a nessun database, quindi funziona anche a stack spento.
#
#   task db-schema
#   task db-schema OUT=schema.md
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"

OUT_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -OutFile|--out) OUT_FILE="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

# Le classi @Entity, con il modulo a cui appartengono.
ENTITY_FILES="$(grep -rl -E '^[[:space:]]*@Entity\b' "$DEMO_DIR" --include='*.java' 2>/dev/null | sort || true)"

render() {
  echo "# Schema concettuale e logico della base dati"
  echo ""
  if [ -z "$ENTITY_FILES" ]; then
    cat <<'EOF'
Nessuna classe `@Entity` trovata: il progetto non ha ancora persistenza.

Le entity si riconoscono cosi':

```java
@Entity
@Table(name = "ordini")
public class OrdineEntity { ... }
```
EOF
    return
  fi

  count="$(printf '%s\n' "$ENTITY_FILES" | grep -c '.')"
  echo "Ricavato dalle classi \`@Entity\` del progetto: $count tabella/e."
  echo ""

  # Una passata sola: awk emette le tre sezioni in tre file temporanei.
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2016
  awk -v demo="$DEMO_DIR" -v tmp="$tmp" '
    function snake(s,   out) {
      out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c ~ /[A-Z]/ && i > 1) out = out "_" tolower(c)
        else out = out tolower(c)
      }
      return out
    }
    function sqltype(t, isEnum, len) {
      if (isEnum) return "VARCHAR(255)"
      if (t == "String") return (len > 0) ? "VARCHAR(" len ")" : "VARCHAR(255)"
      if (t == "Long" || t == "long") return "BIGINT"
      if (t == "Integer" || t == "int") return "INTEGER"
      if (t == "Short" || t == "short") return "SMALLINT"
      if (t == "Double" || t == "double") return "DOUBLE PRECISION"
      if (t == "Float" || t == "float") return "REAL"
      if (t == "Boolean" || t == "boolean") return "BOOLEAN"
      if (t == "BigDecimal") return "NUMERIC(19,2)"
      if (t == "LocalDate") return "DATE"
      if (t == "LocalDateTime" || t == "Instant") return "TIMESTAMP"
      if (t == "LocalTime") return "TIME"
      if (t == "UUID") return "UUID"
      return "VARCHAR(255)"
    }
    function register() {
      if (regDone) return
      regDone = 1
      print table "|" module "|" className >> (tmp "/tables")
    }
    function flush_field(   ann, isFk, fk, target, kind, colName, type, key, nullable, note, inner) {
      if (fieldName == "") return
      register()
      ann = pending
      if (ann ~ /@Transient/) { pending = ""; fieldName = ""; return }

      if (ann ~ /@ManyToOne/ || ann ~ /@OneToOne/) {
        fk = ""
        if (match(ann, /@JoinColumn[^)]*name[[:space:]]*=[[:space:]]*"[^"]+"/)) {
          fk = substr(ann, RSTART, RLENGTH)
          sub(/.*name[[:space:]]*=[[:space:]]*"/, "", fk)
          sub(/".*/, "", fk)
        }
        if (fk == "") fk = snake(fieldName) "_id"
        target = fieldType; sub(/Entity$/, "", target)
        nullable = (ann ~ /optional[[:space:]]*=[[:space:]]*false/) ? "no" : "si"
        print "| `" fk "` | BIGINT | FK | " nullable " | riferimento a " target " |" >> (tmp "/cols_" table)
        print "        BIGINT " fk " FK" >> (tmp "/mer_" table)
        kind = (ann ~ /@OneToOne/) ? "uno a uno" : "molti a uno"
        print "- `" className "` -> `" target "` (" kind ", colonna `" fk "`)" >> (tmp "/relations")
        print table "|" snake(target) "|" kind >> (tmp "/merrel")
        pending = ""; fieldName = ""
        return
      }
      if (ann ~ /@OneToMany/ || ann ~ /@ManyToMany/) {
        target = fieldType
        if (match(target, /<[[:space:]]*[A-Za-z0-9_]+[[:space:]]*>/)) {
          inner = substr(target, RSTART + 1, RLENGTH - 2)
          gsub(/[[:space:]]/, "", inner)
          target = inner
        }
        sub(/Entity$/, "", target)
        kind = (ann ~ /@ManyToMany/) ? "molti a molti (tabella di collegamento)" : "uno a molti (la FK sta nell'\''altra tabella)"
        print "- `" className "` -> `" target "` (" kind ")" >> (tmp "/relations")
        pending = ""; fieldName = ""
        return
      }

      isEnum = (ann ~ /@Enumerated/)
      len = 0
      if (match(ann, /length[[:space:]]*=[[:space:]]*[0-9]+/)) {
        len = substr(ann, RSTART, RLENGTH); sub(/.*=[[:space:]]*/, "", len); len = len + 0
      }
      colName = snake(fieldName)
      if (match(ann, /@Column[^)]*name[[:space:]]*=[[:space:]]*"[^"]+"/)) {
        colName = substr(ann, RSTART, RLENGTH)
        sub(/.*name[[:space:]]*=[[:space:]]*"/, "", colName)
        sub(/".*/, "", colName)
      }
      key = (ann ~ /@Id/) ? "PK" : ""
      nullable = (key == "PK" || ann ~ /nullable[[:space:]]*=[[:space:]]*false/) ? "no" : "si"
      note = ""
      if (ann ~ /@GeneratedValue/) note = "generato automaticamente"
      if (ann ~ /unique[[:space:]]*=[[:space:]]*true/) note = (note == "") ? "univoco" : note ", univoco"
      if (isEnum) note = (note == "") ? "enum salvato come stringa" : note ", enum salvato come stringa"
      type = sqltype(fieldType, isEnum, len)

      print "| `" colName "` | " type " | " key " | " nullable " | " note " |" >> (tmp "/cols_" table)
      shorttype = type; sub(/\(.*\)/, "", shorttype)
      print "        " shorttype " " colName ((key == "PK") ? " PK" : "") >> (tmp "/mer_" table)
      if (key != "FK") print colName >> (tmp "/attrs_" table)
      pending = ""; fieldName = ""
    }

    FNR == 1 {
      module = FILENAME
      sub(demo "/", "", module)
      sub(/\/.*/, "", module)
      className = FILENAME
      sub(/.*\//, "", className); sub(/\.java$/, "", className)
      table = snake(className)
      pending = ""; fieldName = ""; regDone = 0
    }
    /@Table[[:space:]]*\([^)]*name[[:space:]]*=/ {
      t = $0
      sub(/.*name[[:space:]]*=[[:space:]]*"/, "", t); sub(/".*/, "", t)
      if (t != "") table = t
    }
    /^[[:space:]]*@[A-Za-z]/ { pending = pending " " $0; next }
    /^[[:space:]]*(private|protected|public)[[:space:]]+[A-Za-z0-9_<>,\[\] .]+[[:space:]]+[A-Za-z0-9_]+[[:space:]]*(=[^;]*)?;[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*(private|protected|public)[[:space:]]+/, "", line)
      sub(/[[:space:]]*(=[^;]*)?;[[:space:]]*$/, "", line)
      fieldName = line; sub(/.*[[:space:]]/, "", fieldName)
      fieldType = line; sub(/[[:space:]]+[A-Za-z0-9_]+$/, "", fieldType)
      gsub(/[[:space:]]/, "", fieldType)
      flush_field()
      next
    }
    { pending = "" }
  ' $ENTITY_FILES

  # --- Concettuale ------------------------------------------------------------
  echo "## Modello concettuale"
  echo ""
  while IFS='|' read -r table module class; do
    [ -z "$table" ] && continue
    attrs="$(tr '\n' ',' <"$tmp/attrs_$table" 2>/dev/null | sed 's/,$//; s/,/, /g')"
    echo "- **$(printf '%s' "$class" | sed 's/Entity$//')** (modulo \`$module\`): $attrs"
  done <"$tmp/tables"
  echo ""

  if [ -s "$tmp/relations" ]; then
    echo "**Relazioni**"
    echo ""
    sort -u "$tmp/relations"
    echo ""
  fi

  echo '```mermaid'
  echo "erDiagram"
  while IFS='|' read -r table module class; do
    [ -z "$table" ] && continue
    echo "    $(printf '%s' "$table" | tr 'a-z' 'A-Z') {"
    cat "$tmp/mer_$table" 2>/dev/null
    echo "    }"
  done <"$tmp/tables"
  if [ -f "$tmp/merrel" ]; then
    while IFS='|' read -r from to kind; do
      [ -z "$from" ] && continue
      case "$kind" in
        "uno a uno") card='||--||' ;;
        *) card='}o--||' ;;
      esac
      echo "    $(printf '%s' "$from" | tr 'a-z' 'A-Z') $card $(printf '%s' "$to" | tr 'a-z' 'A-Z') : \"\""
    done <"$tmp/merrel"
  fi
  echo '```'
  echo ""

  # --- Logico -----------------------------------------------------------------
  echo "## Modello logico"
  echo ""
  while IFS='|' read -r table module class; do
    [ -z "$table" ] && continue
    echo "### Tabella \`$table\`"
    echo ""
    echo "Modulo \`$module\`, classe \`$class\`."
    echo ""
    echo "| Colonna | Tipo | Chiave | Null | Note |"
    echo "| :--- | :--- | :---: | :---: | :--- |"
    cat "$tmp/cols_$table" 2>/dev/null
    echo ""
  done <"$tmp/tables"

  cat <<'EOF'
> Le tabelle le crea Hibernate all'avvio (`ddl-auto: update`) leggendo queste
> stesse classi: quello che vedi qui e' quello che troverai nel database. I
> nomi non scritti a mano seguono la regola CamelCase -> snake_case, suffisso
> `Entity` compreso: se preferisci un altro nome, scrivilo tu con
> `@Table(name = "...")`.
EOF
  rm -rf "$tmp"
}

if [ -n "$OUT_FILE" ]; then
  render >"$OUT_FILE"
  echo "Schema scritto in $OUT_FILE"
else
  render
fi
