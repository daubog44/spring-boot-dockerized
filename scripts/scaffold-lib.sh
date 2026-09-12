#!/usr/bin/env bash
# Funzioni condivise dagli script POSIX che leggono o cambiano la struttura del
# progetto. Equivalente, per quello che serve di qua, di scaffold-lib.ps1.
#
#   . "$SCRIPT_DIR/scaffold-lib.sh"

# Un progetto Docker Compose per copia del template, col nome della cartella
# del repository (come fanno il Taskfile e dev-lib.sh).
if [ -z "${COMPOSE_PROJECT_NAME:-}" ]; then
  COMPOSE_PROJECT_NAME="$(basename "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9_-]+/-/g; s/^[^a-z0-9]+//')"
  export COMPOSE_PROJECT_NAME
fi

# Il pacchetto Java di base (esame, it.rossi...). Non sta in un file di
# configurazione: e' quello di Eureka meno l'ultimo pezzo (esame.namingserver
# -> esame). Lo cambia task set-package, e new-service lo segue da solo.
base_package() { # cartella dell'aggregatore
  local aggr="$1" file pkg
  while IFS= read -r file; do
    pkg="$(sed -n 's/^[[:space:]]*package[[:space:]][[:space:]]*\([A-Za-z0-9_.]*\)[[:space:]]*;.*/\1/p' "$file" | head -n 1)"
    case "$pkg" in
      *.*) echo "${pkg%.*}"; return 0 ;;
    esac
  done < <(grep -rl --include='*.java' '@SpringBootApplication' "$aggr/naming-server/src/main/java" "$aggr"/*/src/main/java 2>/dev/null)
  echo "esame"
}

# Il pacchetto Java di un modulo: quello di base piu' il nome del modulo senza
# trattini (product-service -> <base>.productservice). Equivalente bash di
# Get-ModulePackage in scaffold-lib.ps1.
sb_module_package() { # modulo, cartella dell'aggregatore
  printf '%s.%s' "$(base_package "$2")" "$(printf '%s' "$1" | tr -cd 'a-zA-Z0-9')"
}

# Una riga di avanzamento, indentata come le altre. Equivalente bash di
# Write-Step in scaffold-lib.ps1.
sb_step() { # messaggio
  printf '  %s\n' "$1"
}

# Il JDK con cui Maven compilera': quello di JAVA_HOME se c'e', se no il java
# del PATH. Stampa "versione|cartella" (25|/usr/lib/jvm/temurin-25), o niente
# e ritorna 1 se non ne trova.
machine_jdk() {
  local java="" out ver home
  if [ -n "${JAVA_HOME:-}" ]; then
    for java in "$JAVA_HOME/bin/java" "$JAVA_HOME/bin/java.exe"; do
      [ -x "$java" ] && break
      java=""
    done
  fi
  [ -n "$java" ] || java="$(command -v java 2>/dev/null || true)"
  [ -n "$java" ] || return 1
  out="$("$java" -XshowSettings:properties -version 2>&1 | tr -d '\r')" || true
  ver="$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*java\.specification\.version = //p' | head -n 1)"
  home="$(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*java\.home = //p' | head -n 1)"
  # Java 8 si presenta come 1.8.
  ver="${ver#1.}"
  case "$ver" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s|%s\n' "$ver" "$(printf '%s' "$home" | tr '\\' '/')"
}

# La versione di Java del progetto: <java.version> del pom aggregatore.
project_java_version() { # cartella dell'aggregatore
  grep -oE '<java\.version>[0-9]+</java\.version>' "$1/pom.xml" | head -n 1 | grep -oE '[0-9]+' || true
}

# --- I moduli con un database, avviati per interrogarlo -----------------------
# Li usano task seed-data e task db-schema. Il lavoro vero lo fa il pacchetto
# devdata di common-dto, dentro l'applicazione: qui si compila, si avvia il jar
# con le proprieta' giuste e si leggono le sue righe [dev-data].

# Una riga "nome|entity|h2" per ogni modulo con spring-boot-starter-data-jpa:
# entity = 1 se ha gia' delle @Entity, h2 = 1 se ha H2 fra le dipendenze.
jpa_modules() { # cartella dell'aggregatore
  local aggr="$1" dir name ent h2
  for dir in "$aggr"/*/; do
    dir="${dir%/}"
    name="$(basename "$dir")"
    [ -f "$dir/pom.xml" ] || continue
    grep -q '<artifactId>spring-boot-starter-data-jpa</artifactId>' "$dir/pom.xml" || continue
    ent=0
    grep -rqE --include='*.java' '^[[:space:]]*@(jakarta\.persistence\.)?Entity([^A-Za-z0-9_]|$)' "$dir/src/main/java" 2>/dev/null && ent=1
    h2=0
    grep -q '<artifactId>h2</artifactId>' "$dir/pom.xml" && h2=1
    printf '%s|%s|%s\n' "$name" "$ent" "$h2"
  done
}

java_exe() {
  local j
  if [ -n "${JAVA_HOME:-}" ]; then
    for j in "$JAVA_HOME/bin/java" "$JAVA_HOME/bin/java.exe"; do
      [ -x "$j" ] && { printf '%s\n' "$j"; return 0; }
    done
  fi
  command -v java 2>/dev/null
}

# Un percorso che java capisce anche su Windows (Git Bash): C:/Users/...
native_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

# Compila i moduli (separati da virgola), e common-dto da cui dipendono.
build_modules() { # cartella dell'aggregatore, file di log, moduli
  (cd "$1" && ./mvnw -B -q -pl "$3" -am package -Dmaven.test.skip=true) >"$2" 2>&1
}

# Avvia il jar di un modulo senza server web ne' Eureka, su un H2 in memoria
# (h2 = 1) o sul database suo (h2 = 0), e aspetta che devdata finisca.
# L'output va nel file di log; l'exit code e' quello dell'applicazione.
devdata_run() { # aggregatore, modulo, h2, file di log, argomenti in piu'...
  local aggr="$1" module="$2" h2="$3" log="$4" jar java limiter=""
  shift 4
  jar="$(ls -t "$aggr/$module/target/"*.jar 2>/dev/null | grep -vE '(sources|javadoc|plain)\.jar$' | head -n 1)"
  if [ -z "$jar" ]; then
    echo "manca il jar in $module/target: compila prima (task build)" >"$log"
    return 250
  fi
  java="$(java_exe)" || true
  if [ -z "$java" ]; then
    echo "java non trovato: installa un JDK (task check)" >"$log"
    return 251
  fi
  set -- --spring.main.web-application-type=none --spring.main.banner-mode=off --logging.level.root=WARN \
    --eureka.client.enabled=false --spring.cloud.discovery.enabled=false \
    --spring.cloud.service-registry.auto-registration.enabled=false --spring.sql.init.mode=never \
    --dev-data.exit=true "$@"
  if [ "$h2" = "1" ]; then
    # Un database vuoto tutto suo: quello del progetto non viene toccato.
    set -- "$@" '--spring.datasource.url=jdbc:h2:mem:devdata;DB_CLOSE_DELAY=-1' \
      --spring.datasource.driver-class-name=org.h2.Driver --spring.datasource.username=sa \
      --spring.datasource.password= --spring.jpa.hibernate.ddl-auto=create \
      --spring.jpa.database-platform=org.hibernate.dialect.H2Dialect \
      --spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect \
      --spring.flyway.enabled=false --spring.liquibase.enabled=false
  fi
  # timeout di coreutils, se c'e' (su Windows non quello di System32).
  if timeout --version >/dev/null 2>&1; then limiter="timeout 180"; fi
  $limiter "$java" -jar "$(native_path "$jar")" "$@" >"$log" 2>&1
}

# Le righe [dev-data] di un log, senza il prefisso.
devdata_lines() { # file di log
  sed -n 's/^\[dev-data\] //p' "$1" | tr -d '\r'
}

# Mostra com'e' andata; ritorna 0 se tutto bene.
devdata_report() { # modulo, exit code, file di log
  local module="$1" code="$2" log="$3" lines
  lines="$(devdata_lines "$log")"
  if [ -n "$lines" ]; then
    printf '%s\n' "$lines" | sed 's/^/    /'
  fi
  if [ "$code" = "0" ] && [ -n "$lines" ]; then return 0; fi
  if [ "$code" = "250" ] || [ "$code" = "251" ]; then
    echo "    $(cat "$log")"
  elif [ "$code" = "124" ]; then
    echo "    non ha finito in 180 secondi (aspetta un database o un altro servizio?)"
  elif [ -z "$lines" ] && [ "$code" = "0" ]; then
    echo "    non usa common-dto, che porta devdata: task add-dep SERVICE=$module DEP=common-dto"
  elif [ -z "$lines" ]; then
    echo "    non si e' avviato (log completo: $log)"
    grep -E 'ERROR|Caused by|Description:|Action:|APPLICATION FAILED|Exception' "$log" | grep -vE '^[[:space:]]+at ' | tail -n 12 | sed 's/^/      /'
  fi
  return 1
}

# Le due chiavi che servono perche' un data.sql giri dopo Hibernate, anche su
# PostgreSQL (senza, Spring lo esegue subito, prima che le tabelle esistano):
# spring.jpa.defer-datasource-initialization e spring.sql.init.mode. Le
# aggiunge sotto spring: se mancano; se ci sono gia' non tocca niente.
ensure_sql_init() { # application.yml
  local yml="$1" cr=""
  grep -q 'defer-datasource-initialization' "$yml" && return 0
  grep -q $'\r' "$yml" && cr=$'\r'
  awk -v cr="$cr" '
    BEGIN { in_spring=0 }
    /^spring:\r?$/ { in_spring=1; print; next }
    in_spring && /^[^ \t\r]/ {
      print "  sql:" cr
      print "    init:" cr
      print "      mode: always" cr
      print "      continue-on-error: true" cr
      print ""
      in_spring=0
      print
      next
    }
    in_spring && /^  jpa:\r?$/ {
      print
      print "    defer-datasource-initialization: true" cr
      next
    }
    { print }
    END {
      if (in_spring) {
        print "  sql:" cr
        print "    init:" cr
        print "      mode: always" cr
        print "      continue-on-error: true" cr
      }
    }
  ' "$yml" >"$yml.tmp" && mv "$yml.tmp" "$yml"
}

# dev-data.rows nell'application.yml: lo aggiorna se c'e', se no lo aggiunge in fondo.
set_devdata_rows() { # application.yml, righe
  local yml="$1" rows="$2" cr=""
  grep -q $'\r' "$yml" && cr=$'\r'
  if awk '/^dev-data:/{f=1; next} f && /^[^ \t\r]/{f=0} f && /^[ \t]+rows:/{found=1} END{exit !found}' "$yml"; then
    awk -v n="$rows" '/^dev-data:/{f=1; print; next} f && /^[^ \t\r]/{f=0} f && /^[ \t]+rows:/{sub(/rows:[ \t]*[0-9]+/, "rows: " n)} {print}' "$yml" >"$yml.tmp" && mv "$yml.tmp" "$yml"
  elif grep -qE '^dev-data:[[:space:]]*$' "$yml"; then
    awk -v n="$rows" -v cr="$cr" '{print} /^dev-data:/{print "  rows: " n cr}' "$yml" >"$yml.tmp" && mv "$yml.tmp" "$yml"
  else
    # L'ultima riga potrebbe non avere l'a capo: prima lo aggiungiamo.
    [ -n "$(tail -c 1 "$yml")" ] && printf '%s\n' "$cr" >>"$yml"
    {
      printf '%s\n' "$cr"
      printf '%s\n' "# Dati di prova (task seed-data): all'avvio le tabelle ancora vuote si$cr"
      printf '%s\n' "# riempiono da sole con righe inventate, passando da Hibernate. 0 = spento.$cr"
      printf '%s\n' "dev-data:$cr"
      printf '%s\n' "  rows: $rows$cr"
    } >>"$yml"
  fi
}
