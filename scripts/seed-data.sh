#!/usr/bin/env bash
# Genera dati di prova a partire dalle @Entity: un data.sql per modulo.
# Equivalente POSIX di scripts/seed-data.ps1.
#
# Legge le classi @Entity, ne ricava tabelle, colonne e relazioni, e scrive un
# src/main/resources/data.sql con le INSERT. Spring Boot lo esegue all'avvio,
# dopo che Hibernate ha creato le tabelle.
#
#   task seed-data
#   task seed-data SERVICE=ordini-service ROWS=10
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"

MODULE=""
ROWS=5
while [ $# -gt 0 ]; do
  case "$1" in
    -Module|--module) MODULE="$2"; shift 2 ;;
    -Rows|--rows) ROWS="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

# --- Valori inventati, ma che sembrano veri ----------------------------------

NOMI=('Rossi S.r.l.' 'Bianchi SPA' 'Verdi & Figli' 'Neri Logistica' 'Gialli Trasporti' 'Azzurri Import' 'Ferrari Componenti' 'Moretti Distribuzione')
CITTA=('Bolzano' 'Trento' 'Verona' 'Milano' 'Bologna' 'Padova' 'Brescia' 'Modena')
PERSONE=('Mario Rossi' 'Anna Bianchi' 'Luca Verdi' 'Giulia Neri' 'Paolo Gialli' 'Sara Azzurri' 'Marco Ferrari' 'Elena Moretti')
DESCRIZIONI=('Prima consegna del mese' 'Ordine urgente' 'Riassortimento magazzino' 'Reso da cliente' 'Fornitura periodica' 'Campione gratuito' 'Ordine ricorrente' 'Spedizione parziale')
PRODOTTI=('Vite M6' 'Dado esagonale' 'Cuscinetto 6203' 'Guarnizione 40mm' 'Molla a trazione' 'Rondella piana' 'Perno filettato' 'Boccola in ottone')

# Un valore dalla tabella, con il numero di riga appeso quando la tabella
# finisce: cosi' anche con ROWS=50 non nascono due righe uguali, che su una
# colonna unique = true farebbero fallire l'avvio.
pick() {
  local idx="$1"; shift
  local n=$# value
  value="${@:$(( (idx - 1) % n + 1 )):1}"
  if [ "$idx" -gt "$n" ]; then value="$value $idx"; fi
  printf '%s' "$value"
}

string_value() {
  local col="$1" idx="$2"
  case "$col" in
    *email*)                                        printf 'utente%s@esempio.it' "$idx" ;;
    *citta*|*city*|*comune*|*luogo*)                pick "$idx" "${CITTA[@]}" ;;
    *indirizzo*|*via*|*address*)                    printf 'Via Roma %s' "$(( idx * 3 ))" ;;
    *codice*|*sigla*|*targa*|*cod*)                 printf 'COD-%03d' "$idx" ;;
    *descrizione*|*note*|*testo*)                   pick "$idx" "${DESCRIZIONI[@]}" ;;
    *prodotto*|*articolo*|*item*)                   pick "$idx" "${PRODOTTI[@]}" ;;
    *cliente*|*fornitore*|*ragione*|*azienda*|*societa*) pick "$idx" "${NOMI[@]}" ;;
    *nome*|*cognome*|*utente*|*referente*|*responsabile*) pick "$idx" "${PERSONE[@]}" ;;
    *stato*|*status*|*tipo*)                        printf 'VALORE_%s' "$idx" ;;
    *)                                              printf '%s %s' "${col//_/ }" "$idx" ;;
  esac
}

# Apici singoli raddoppiati: e' l'escape dell'SQL.
sql_quote() {
  local v="$1"
  printf "'%s'" "${v//\'/\'\'}"
}

gen_value() {
  # $1 colonna, $2 tipo java, $3 valori enum (separati da spazi), $4 indice
  local col="$1" type="$2" enums="$3" idx="$4"
  if [ -n "$enums" ]; then
    local arr=($enums)
    printf "'%s'" "${arr[$(( (idx - 1) % ${#arr[@]} ))]}"
    return
  fi
  case "$type" in
    String)
      sql_quote "$(string_value "$col" "$idx")" ;;
    Long|long|Integer|int|Short|short)
      case "$col" in
        *quantita*|*pezzi*|*numero*|*qta*|*scorta*) printf '%s' "$(( (idx * 7) % 50 + 1 ))" ;;
        *) printf '%s' "$(( idx * 10 ))" ;;
      esac ;;
    Double|double|Float|float|BigDecimal)
      awk -v i="$idx" 'BEGIN { printf "%.2f", i * 12.5 + 0.5 }' ;;
    Boolean|boolean)
      if [ $(( idx % 2 )) -eq 0 ]; then printf 'true'; else printf 'false'; fi ;;
    LocalDate)
      printf "'%s'" "$(date -d "-$idx days" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)" ;;
    LocalDateTime|Instant)
      printf "'%s'" "$(date -d "-$idx hours" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')" ;;
    LocalTime)
      printf "'%s'" "$(date -d "-$idx hours" '+%H:%M:%S' 2>/dev/null || date '+%H:%M:%S')" ;;
    *)
      printf "'valore%s'" "$idx" ;;
  esac
}

# I valori veri di un enum stanno nel suo file .java.
enum_values() {
  local srcdir="$1" type="$2" file
  file="$(find "$srcdir" -name "$type.java" -print -quit 2>/dev/null || true)"
  if [ -z "$file" ]; then echo "VALORE_A VALORE_B"; return; fi
  local found
  found="$(awk -v t="$type" '
    !on && $0 ~ ("enum[ \t]+" t "([ \t{]|$)") { on = 1; sub(/.*\{/, "") }
    on {
      line = $0
      gsub(/\([^)]*\)/, "", line)
      if (match(line, /[;}]/)) { line = substr(line, 1, RSTART - 1); stop = 1 }
      n = split(line, parts, /[,  \t]+/)
      for (i = 1; i <= n; i++) if (parts[i] ~ /^[A-Z][A-Z0-9_]*$/) print parts[i]
      if (stop) exit
    }' "$file" | awk '!seen[$0]++' | tr '\n' ' ')"
  if [ -z "${found// /}" ]; then echo "VALORE_A VALORE_B"; else echo "$found"; fi
}

# --- Lettura delle entity di un modulo ---------------------------------------
# Emette una specifica a righe:
#   E|Classe|tabella
#   C|Classe|colonna|TipoJava|TipoEnumOppureVuoto
#   F|Classe|colonna_fk|ClasseBersaglio

read_entities() {
  local srcdir="$1"
  local files
  files="$(grep -rl -E '^[[:space:]]*@Entity\b' "$srcdir" --include='*.java' 2>/dev/null | sort || true)"
  [ -z "$files" ] && return 0
  # shellcheck disable=SC2086
  awk '
    function snake(s,   out, i, c) {
      out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c ~ /[A-Z]/ && i > 1) out = out "_" tolower(c)
        else out = out tolower(c)
      }
      return out
    }
    function register() {
      if (regDone) return
      regDone = 1
      print "E|" className "|" table
    }
    function flush_field(   ann, fk, target, colName, enumType, inner) {
      if (fieldName == "") return
      ann = pending
      pending = ""
      if (ann ~ /@Transient/ || ann ~ /@OneToMany/ || ann ~ /@ManyToMany/) { fieldName = ""; return }
      register()

      if (ann ~ /@ManyToOne/ || ann ~ /@OneToOne/) {
        fk = ""
        if (match(ann, /@JoinColumn[^)]*name[[:space:]]*=[[:space:]]*"[^"]+"/)) {
          fk = substr(ann, RSTART, RLENGTH)
          sub(/.*name[[:space:]]*=[[:space:]]*"/, "", fk)
          sub(/".*/, "", fk)
        }
        if (fk == "") fk = snake(fieldName) "_id"
        print "F|" className "|" fk "|" fieldType
        fieldName = ""
        return
      }
      # La chiave primaria generata la lascia fare al database.
      if (ann ~ /@Id[^A-Za-z]/ && ann ~ /@GeneratedValue/) { fieldName = ""; return }

      colName = snake(fieldName)
      if (match(ann, /@Column[^)]*name[[:space:]]*=[[:space:]]*"[^"]+"/)) {
        colName = substr(ann, RSTART, RLENGTH)
        sub(/.*name[[:space:]]*=[[:space:]]*"/, "", colName)
        sub(/".*/, "", colName)
      }
      enumType = (ann ~ /@Enumerated/) ? fieldType : ""
      print "C|" className "|" colName "|" fieldType "|" enumType
      fieldName = ""
    }

    FNR == 1 {
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
    /^[[:space:]]*@[A-Za-z]/ { pending = pending " " $0 " "; next }
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
  ' $files
}

# --- Ordine di inserimento: prima chi non dipende da nessuno -----------------

insert_order() {
  awk -F'|' '
    $1 == "E" { cls[++n] = $2 }
    $1 == "F" { dep[$2] = dep[$2] " " $4 }
    END {
      for (i = 1; i <= n; i++) known[cls[i]] = 1
      placed = 0
      while (placed < n) {
        progress = 0
        for (i = 1; i <= n; i++) {
          c = cls[i]
          if (out[c]) continue
          ready = 1
          m = split(dep[c], d, " ")
          for (j = 1; j <= m; j++) {
            t = d[j]
            if (t == "" || t == c) continue
            if (known[t] && !out[t]) { ready = 0; break }
          }
          if (ready) { print c; out[c] = 1; placed++; progress = 1 }
        }
        if (!progress) {
          # Ciclo fra entity: se ne sceglie una e si va avanti.
          for (i = 1; i <= n; i++) if (!out[cls[i]]) { print cls[i]; out[cls[i]] = 1; placed++; break }
        }
      }
    }' "$1"
}

# --- Generazione --------------------------------------------------------------

TARGETS=""
if [ -n "$MODULE" ]; then
  if [ ! -f "$DEMO_DIR/$MODULE/pom.xml" ]; then
    echo "Modulo '$MODULE' non trovato." >&2
    exit 1
  fi
  TARGETS="$DEMO_DIR/$MODULE"
else
  for dir in "$DEMO_DIR"/*/; do
    [ -f "$dir/pom.xml" ] && TARGETS="$TARGETS ${dir%/}"
  done
fi

echo ""
echo "==> Dati di prova dalle @Entity"
echo ""

GENERATED=0
for target in $TARGETS; do
  name="$(basename "$target")"
  srcdir="$target/src/main/java"
  [ -d "$srcdir" ] || continue

  spec="$(mktemp)"
  read_entities "$srcdir" >"$spec"
  if [ ! -s "$spec" ]; then rm -f "$spec"; continue; fi

  sql="$(mktemp)"
  {
    echo "-- Dati di prova generati da task seed-data."
    echo "-- Spring Boot esegue questo file all'avvio, dopo che Hibernate ha"
    echo "-- creato le tabelle. Modificalo pure: non viene sovrascritto se non"
    echo "-- rilanci il comando."
    echo ""
  } >"$sql"

  tables=0
  for class in $(insert_order "$spec"); do
    table="$(awk -F'|' -v c="$class" '$1 == "E" && $2 == c { print $3; exit }' "$spec")"
    [ -n "$table" ] || continue
    cols="$(awk -F'|' -v c="$class" '($1 == "C" || $1 == "F") && $2 == c { print $1 "|" $3 "|" $4 "|" $5 }' "$spec")"
    [ -n "$cols" ] || continue
    tables=$(( tables + 1 ))
    echo "-- $class" >>"$sql"
    for idx in $(seq 1 "$ROWS"); do
      names=""
      values=""
      while IFS='|' read -r kind col type enumtype; do
        [ -z "$kind" ] && continue
        names="$names, $col"
        if [ "$kind" = "F" ]; then
          # Punta a una riga che esiste di sicuro: la tabella a cui punta e'
          # stata riempita prima, con lo stesso numero di righe.
          values="$values, $(( ((idx - 1) % ROWS) + 1 ))"
        else
          enums=""
          [ -n "$enumtype" ] && enums="$(enum_values "$srcdir" "$enumtype")"
          values="$values, $(gen_value "$col" "$type" "$enums" "$idx")"
        fi
      done <<<"$cols"
      echo "INSERT INTO $table (${names#, }) VALUES (${values#, });" >>"$sql"
    done
    echo "" >>"$sql"
  done

  mkdir -p "$target/src/main/resources"
  mv "$sql" "$target/src/main/resources/data.sql"
  echo "  demo/$name/src/main/resources/data.sql  ($tables tabella/e x $ROWS righe)"

  # Senza queste due proprieta' il file non viene eseguito, o viene eseguito
  # prima che le tabelle esistano.
  yml="$target/src/main/resources/application.yml"
  if [ -f "$yml" ]; then
    if ! grep -q 'defer-datasource-initialization' "$yml"; then
      N="$(grep -nE '^[[:space:]]+jpa:' "$yml" | head -n 1 | cut -d: -f1)"
      if [ -n "$N" ]; then
        awk -v n="$N" '{ print } NR == n { print "    defer-datasource-initialization: true" }' "$yml" >"$yml.tmp" && mv "$yml.tmp" "$yml"
      else
        N="$(grep -nE '^eureka:' "$yml" | head -n 1 | cut -d: -f1)"
        [ -n "$N" ] && awk -v n="$((N - 1))" '{ print } NR == n { print "  jpa:"; print "    defer-datasource-initialization: true"; print "" }' "$yml" >"$yml.tmp" && mv "$yml.tmp" "$yml"
      fi
    fi
    if ! grep -qE '^[[:space:]]+sql:' "$yml"; then
      N="$(grep -nE '^eureka:' "$yml" | head -n 1 | cut -d: -f1)"
      if [ -n "$N" ]; then
        awk -v n="$((N - 1))" '{ print } NR == n { print "  sql:"; print "    init:"; print "      mode: always"; print "" }' "$yml" >"$yml.tmp" && mv "$yml.tmp" "$yml"
      fi
    fi
    echo "  demo/$name/src/main/resources/application.yml (esecuzione di data.sql)"
  fi

  rm -f "$spec"
  GENERATED=$(( GENERATED + 1 ))
done

echo ""
if [ "$GENERATED" -eq 0 ]; then
  echo "Nessuna @Entity trovata: non c'e' niente da popolare."
  echo ""
  echo "  Crea prima le entity del tuo dominio, poi rilancia questo comando."
  echo ""
  exit 0
fi
echo "Dati di prova generati."
echo ""
echo "  task dev          riavvia: le tabelle si riempiono da sole"
echo "  task db-schema    lo schema che questi dati rispettano"
echo ""
echo "  Su PostgreSQL le INSERT vengono rieseguite a ogni avvio: se ti trovi"
echo "  righe doppie, svuota con task docker-reset. Con H2 in memoria non"
echo "  succede, perche' il database riparte vuoto ogni volta."
echo ""
