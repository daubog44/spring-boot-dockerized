#!/usr/bin/env bash
# Funzioni condivise dagli script POSIX che leggono o cambiano la struttura del
# progetto. Equivalente, per quello che serve di qua, di scaffold-lib.ps1.
#
#   . "$SCRIPT_DIR/scaffold-lib.sh"

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
