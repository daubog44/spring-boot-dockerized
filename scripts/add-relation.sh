#!/usr/bin/env bash
# Aggiunge una relazione JPA tra due entita' dello stesso microservizio.
# Equivalente POSIX di scripts/add-relation.ps1.
#
#   task add-relation SERVICE=catalogo-service FROM=Libro TO=Autore TYPE=many-to-one
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

SERVICE=""
FROM=""
TO=""
TYPE="many-to-one"
FIELD=""
UNIDIRECTIONAL=0
DTO=0

while [ $# -gt 0 ]; do
  case "$1" in
    -Service|--service) SERVICE="$2"; shift 2 ;;
    -From|--from) FROM="$2"; shift 2 ;;
    -To|--to) TO="$2"; shift 2 ;;
    -Type|--type) TYPE="$2"; shift 2 ;;
    -Field|--field) FIELD="$2"; shift 2 ;;
    -Unidirectional|--unidirectional) UNIDIRECTIONAL=1; shift 1 ;;
    -Dto|--dto) DTO=1; shift 1 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$SERVICE" ] || [ -z "$FROM" ] || [ -z "$TO" ]; then
  if [ ! -t 0 ]; then
    echo "Uso: task add-relation SERVICE=<modulo> FROM=<Entita1> TO=<Entita2> [TYPE=many-to-one|one-to-many|many-to-many|one-to-one] [FIELD=<nomeCampo>]" >&2
    exit 1
  fi

  if [ -z "$SERVICE" ]; then
    JPA_MODULES=()
    for d in "$DEMO_DIR"/*; do
      if [ -f "$d/pom.xml" ] && grep -q 'spring-boot-starter-data-jpa' "$d/pom.xml"; then
        JPA_MODULES+=("$(basename "$d")")
      fi
    done
    if [ "${#JPA_MODULES[@]}" -eq 0 ]; then
      echo "Non ci sono moduli con JPA (database) in demo/. Creane uno con task new-service." >&2
      exit 1
    fi
    echo ""
    echo "Seleziona il microservizio con le entita':"
    for i in "${!JPA_MODULES[@]}"; do
      echo "  $((i+1))) ${JPA_MODULES[$i]}"
    done
    printf "  [1] > "
    read -r IDX
    [ -n "$IDX" ] || IDX=1
    SERVICE="${JPA_MODULES[$((IDX-1))]}"
  fi

  MODULE_DIR="$DEMO_DIR/$SERVICE"
  [ -f "$MODULE_DIR/pom.xml" ] || { echo "Non trovo il modulo '$SERVICE' in demo/." >&2; exit 1; }
  PKG="$(sb_module_package "$SERVICE")"
  PKG_PATH="$(printf '%s' "$PKG" | tr '.' '/')"
  ENTITY_DIR="$MODULE_DIR/src/main/java/$PKG_PATH/entity"
  [ -d "$ENTITY_DIR" ] || { echo "Non trovo la cartella entity in $SERVICE ($ENTITY_DIR). Crea prima le entita' con task new-entity." >&2; exit 1; }

  EXISTING_ENTITIES=()
  for ef in "$ENTITY_DIR"/*Entity.java; do
    [ -f "$ef" ] || continue
    bname="$(basename "$ef")"
    EXISTING_ENTITIES+=("${bname%Entity.java}")
  done

  if [ "${#EXISTING_ENTITIES[@]}" -lt 2 ]; then
    echo "Nel modulo '$SERVICE' ci sono meno di 2 entita'. Crea almeno due entita' con task new-entity prima di collegarle." >&2
    exit 1
  fi

  if [ -z "$FROM" ]; then
    echo ""
    echo "Scegli l'entita' di partenza (FROM):"
    for i in "${!EXISTING_ENTITIES[@]}"; do
      echo "  $((i+1))) ${EXISTING_ENTITIES[$i]}"
    done
    printf "  [1] > "
    read -r IDX
    [ -n "$IDX" ] || IDX=1
    FROM="${EXISTING_ENTITIES[$((IDX-1))]}"
  fi

  if [ -z "$TO" ]; then
    CANDIDATES=()
    for e in "${EXISTING_ENTITIES[@]}"; do
      [ "$e" != "$FROM" ] && CANDIDATES+=("$e")
    done
    echo ""
    echo "Scegli l'entita' di arrivo (TO):"
    for i in "${!CANDIDATES[@]}"; do
      echo "  $((i+1))) ${CANDIDATES[$i]}"
    done
    printf "  [1] > "
    read -r IDX
    [ -n "$IDX" ] || IDX=1
    TO="${CANDIDATES[$((IDX-1))]}"
  fi

  echo ""
  echo "Tipo di relazione (1: many-to-one [default], 2: one-to-many, 3: many-to-many, 4: one-to-one):"
  echo "  1) many-to-one"
  echo "  2) one-to-many"
  echo "  3) many-to-many"
  echo "  4) one-to-one"
  printf "  [1] > "
  read -r T_IDX
  case "$T_IDX" in
    2) TYPE="one-to-many" ;;
    3) TYPE="many-to-many" ;;
    4) TYPE="one-to-one" ;;
    *) TYPE="many-to-one" ;;
  esac
fi

MODULE_DIR="$DEMO_DIR/$SERVICE"
[ -f "$MODULE_DIR/pom.xml" ] || { echo "Non trovo il modulo '$SERVICE' in demo/." >&2; exit 1; }

PKG="$(sb_module_package "$SERVICE")"
PKG_PATH="$(printf '%s' "$PKG" | tr '.' '/')"
ENTITY_DIR="$MODULE_DIR/src/main/java/$PKG_PATH/entity"
[ -d "$ENTITY_DIR" ] || { echo "Non trovo la cartella entity in $SERVICE ($ENTITY_DIR)." >&2; exit 1; }

CLEAN_FROM="$(printf '%s' "$FROM" | sed -E 's/Entity$//')"
CLEAN_TO="$(printf '%s' "$TO" | sed -E 's/Entity$//')"

FROM_FILE="$ENTITY_DIR/${CLEAN_FROM}Entity.java"
TO_FILE="$ENTITY_DIR/${CLEAN_TO}Entity.java"

[ -f "$FROM_FILE" ] || { echo "Non trovo l'entita' sorgente: $FROM_FILE" >&2; exit 1; }
[ -f "$TO_FILE" ] || { echo "Non trovo l'entita' target: $TO_FILE" >&2; exit 1; }

TYPE_LOWER="$(printf '%s' "$TYPE" | tr '[:upper:]' '[:lower:]')"

# Helper per camelCase
to_camel() {
  local s="$1"
  local first rest
  first="$(printf '%s' "$s" | cut -c1 | tr '[:upper:]' '[:lower:]')"
  rest="$(printf '%s' "$s" | cut -c2-)"
  printf '%s%s' "$first" "$rest"
}

# Helper per snake_case
to_snake() {
  local s="$1"
  printf '%s' "$s" | sed -E 's/([A-Z])/_\1/g' | sed -E 's/^_//' | tr '[:upper:]' '[:lower:]'
}

FROM_CAMEL="$(to_camel "$CLEAN_FROM")"
TO_CAMEL="$(to_camel "$CLEAN_TO")"
FROM_SNAKE="$(to_snake "$CLEAN_FROM")"
TO_SNAKE="$(to_snake "$CLEAN_TO")"

if [ -n "$FIELD" ]; then
  FROM_FIELD_NAME="$FIELD"
else
  case "$TYPE_LOWER" in
    many-to-one|one-to-one) FROM_FIELD_NAME="$TO_CAMEL" ;;
    one-to-many)            FROM_FIELD_NAME="${TO_CAMEL}List" ;;
    many-to-many)           FROM_FIELD_NAME="${TO_CAMEL}Set" ;;
    *) echo "Tipo relazione non valido: '$TYPE'. Usa many-to-one, one-to-many, many-to-many o one-to-one." >&2; exit 1 ;;
  esac
fi

case "$TYPE_LOWER" in
  many-to-one) TO_FIELD_NAME="${FROM_CAMEL}List" ;;
  one-to-many|one-to-one) TO_FIELD_NAME="$FROM_CAMEL" ;;
  many-to-many) TO_FIELD_NAME="${FROM_CAMEL}Set" ;;
esac

# Aggiunge import a un file se non presente
add_import_if_missing() {
  local file="$1"
  local imp="$2"
  if ! grep -Fq "import $imp;" "$file"; then
    local tmp
    tmp="$(mktemp)"
    awk -v imp="import $imp;" '
      /^import / && !inserted { last_imp=NR }
      { lines[NR]=$0 }
      END {
        for (i=1; i<=NR; i++) {
          print lines[i]
          if (i == last_imp) print imp
        }
      }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  fi
}

# Aggiunge campo prima dell'ultima graffa
add_field_before_last_brace() {
  local file="$1"
  local block="$2"
  local check_field="$3"

  if grep -E -q "\b${check_field}\b" "$file"; then
    echo "Il campo '${check_field}' esiste gia' in $(basename "$file")." >&2
    exit 1
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v blk="$block" '
    { lines[NR]=$0 }
    /^[[:space:]]*}[[:space:]]*$/ { last_brace=NR }
    END {
      for (i=1; i<=NR; i++) {
        if (i == last_brace) {
          print ""
          print blk
        }
        print lines[i]
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

case "$TYPE_LOWER" in
  many-to-one)
    if [ "$UNIDIRECTIONAL" -eq 0 ]; then
      FROM_BLOCK=$(cat <<EOF
    @JsonIgnoreProperties("${TO_FIELD_NAME}")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "${TO_SNAKE}_id")
    private ${CLEAN_TO}Entity ${FROM_FIELD_NAME};
EOF
)
      add_import_if_missing "$FROM_FILE" "com.fasterxml.jackson.annotation.JsonIgnoreProperties"
    else
      FROM_BLOCK=$(cat <<EOF
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "${TO_SNAKE}_id")
    private ${CLEAN_TO}Entity ${FROM_FIELD_NAME};
EOF
)
    fi
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.ManyToOne"
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.JoinColumn"
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.FetchType"
    add_field_before_last_brace "$FROM_FILE" "$FROM_BLOCK" "$FROM_FIELD_NAME"
    sb_step "Aggiunto @ManyToOne $FROM_FIELD_NAME in ${CLEAN_FROM}Entity.java"

    if [ "$UNIDIRECTIONAL" -eq 0 ]; then
      TO_BLOCK=$(cat <<EOF
    @JsonIgnoreProperties("${FROM_FIELD_NAME}")
    @OneToMany(mappedBy = "${FROM_FIELD_NAME}", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<${CLEAN_FROM}Entity> ${TO_FIELD_NAME} = new ArrayList<>();
EOF
)
      add_import_if_missing "$TO_FILE" "jakarta.persistence.OneToMany"
      add_import_if_missing "$TO_FILE" "jakarta.persistence.CascadeType"
      add_import_if_missing "$TO_FILE" "java.util.List"
      add_import_if_missing "$TO_FILE" "java.util.ArrayList"
      add_import_if_missing "$TO_FILE" "com.fasterxml.jackson.annotation.JsonIgnoreProperties"
      add_field_before_last_brace "$TO_FILE" "$TO_BLOCK" "$TO_FIELD_NAME"
      sb_step "Aggiunto @OneToMany $TO_FIELD_NAME in ${CLEAN_TO}Entity.java"
    fi
    ;;

  one-to-many)
    if [ "$UNIDIRECTIONAL" -eq 0 ]; then
      FROM_BLOCK=$(cat <<EOF
    @JsonIgnoreProperties("${TO_FIELD_NAME}")
    @OneToMany(mappedBy = "${TO_FIELD_NAME}", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<${CLEAN_TO}Entity> ${FROM_FIELD_NAME} = new ArrayList<>();
EOF
)
      add_import_if_missing "$FROM_FILE" "com.fasterxml.jackson.annotation.JsonIgnoreProperties"
    else
      FROM_BLOCK=$(cat <<EOF
    @OneToMany(mappedBy = "${TO_FIELD_NAME}", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<${CLEAN_TO}Entity> ${FROM_FIELD_NAME} = new ArrayList<>();
EOF
)
    fi
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.OneToMany"
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.CascadeType"
    add_import_if_missing "$FROM_FILE" "java.util.List"
    add_import_if_missing "$FROM_FILE" "java.util.ArrayList"
    add_field_before_last_brace "$FROM_FILE" "$FROM_BLOCK" "$FROM_FIELD_NAME"
    sb_step "Aggiunto @OneToMany $FROM_FIELD_NAME in ${CLEAN_FROM}Entity.java"

    if [ "$UNIDIRECTIONAL" -eq 0 ]; then
      TO_BLOCK=$(cat <<EOF
    @JsonIgnoreProperties("${FROM_FIELD_NAME}")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "${FROM_SNAKE}_id")
    private ${CLEAN_FROM}Entity ${TO_FIELD_NAME};
EOF
)
      add_import_if_missing "$TO_FILE" "jakarta.persistence.ManyToOne"
      add_import_if_missing "$TO_FILE" "jakarta.persistence.JoinColumn"
      add_import_if_missing "$TO_FILE" "jakarta.persistence.FetchType"
      add_import_if_missing "$TO_FILE" "com.fasterxml.jackson.annotation.JsonIgnoreProperties"
      add_field_before_last_brace "$TO_FILE" "$TO_BLOCK" "$TO_FIELD_NAME"
      sb_step "Aggiunto @ManyToOne $TO_FIELD_NAME in ${CLEAN_TO}Entity.java"
    fi
    ;;

  one-to-one)
    if [ "$UNIDIRECTIONAL" -eq 0 ]; then
      FROM_BLOCK=$(cat <<EOF
    @JsonIgnoreProperties("${TO_FIELD_NAME}")
    @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @JoinColumn(name = "${TO_SNAKE}_id", unique = true)
    private ${CLEAN_TO}Entity ${FROM_FIELD_NAME};
EOF
)
      add_import_if_missing "$FROM_FILE" "com.fasterxml.jackson.annotation.JsonIgnoreProperties"
    else
      FROM_BLOCK=$(cat <<EOF
    @OneToOne(fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    @JoinColumn(name = "${TO_SNAKE}_id", unique = true)
    private ${CLEAN_TO}Entity ${FROM_FIELD_NAME};
EOF
)
    fi
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.OneToOne"
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.JoinColumn"
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.FetchType"
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.CascadeType"
    add_field_before_last_brace "$FROM_FILE" "$FROM_BLOCK" "$FROM_FIELD_NAME"
    sb_step "Aggiunto @OneToOne $FROM_FIELD_NAME in ${CLEAN_FROM}Entity.java"

    if [ "$UNIDIRECTIONAL" -eq 0 ]; then
      TO_BLOCK=$(cat <<EOF
    @JsonIgnoreProperties("${FROM_FIELD_NAME}")
    @OneToOne(mappedBy = "${FROM_FIELD_NAME}", fetch = FetchType.LAZY)
    private ${CLEAN_FROM}Entity ${TO_FIELD_NAME};
EOF
)
      add_import_if_missing "$TO_FILE" "jakarta.persistence.OneToOne"
      add_import_if_missing "$TO_FILE" "jakarta.persistence.FetchType"
      add_import_if_missing "$TO_FILE" "com.fasterxml.jackson.annotation.JsonIgnoreProperties"
      add_field_before_last_brace "$TO_FILE" "$TO_BLOCK" "$TO_FIELD_NAME"
      sb_step "Aggiunto @OneToOne $TO_FIELD_NAME in ${CLEAN_TO}Entity.java"
    fi
    ;;

  many-to-many)
    JOIN_TABLE="${FROM_SNAKE}_${TO_SNAKE}"
    if [ "$UNIDIRECTIONAL" -eq 0 ]; then
      FROM_BLOCK=$(cat <<EOF
    @JsonIgnoreProperties("${TO_FIELD_NAME}")
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "${JOIN_TABLE}",
        joinColumns = @JoinColumn(name = "${FROM_SNAKE}_id"),
        inverseJoinColumns = @JoinColumn(name = "${TO_SNAKE}_id")
    )
    private Set<${CLEAN_TO}Entity> ${FROM_FIELD_NAME} = new HashSet<>();
EOF
)
      add_import_if_missing "$FROM_FILE" "com.fasterxml.jackson.annotation.JsonIgnoreProperties"
    else
      FROM_BLOCK=$(cat <<EOF
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "${JOIN_TABLE}",
        joinColumns = @JoinColumn(name = "${FROM_SNAKE}_id"),
        inverseJoinColumns = @JoinColumn(name = "${TO_SNAKE}_id")
    )
    private Set<${CLEAN_TO}Entity> ${FROM_FIELD_NAME} = new HashSet<>();
EOF
)
    fi
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.ManyToMany"
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.JoinTable"
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.JoinColumn"
    add_import_if_missing "$FROM_FILE" "jakarta.persistence.FetchType"
    add_import_if_missing "$FROM_FILE" "java.util.Set"
    add_import_if_missing "$FROM_FILE" "java.util.HashSet"
    add_field_before_last_brace "$FROM_FILE" "$FROM_BLOCK" "$FROM_FIELD_NAME"
    sb_step "Aggiunto @ManyToMany $FROM_FIELD_NAME in ${CLEAN_FROM}Entity.java"

    if [ "$UNIDIRECTIONAL" -eq 0 ]; then
      TO_BLOCK=$(cat <<EOF
    @JsonIgnoreProperties("${FROM_FIELD_NAME}")
    @ManyToMany(mappedBy = "${FROM_FIELD_NAME}", fetch = FetchType.LAZY)
    private Set<${CLEAN_FROM}Entity> ${TO_FIELD_NAME} = new HashSet<>();
EOF
)
      add_import_if_missing "$TO_FILE" "jakarta.persistence.ManyToMany"
      add_import_if_missing "$TO_FILE" "jakarta.persistence.FetchType"
      add_import_if_missing "$TO_FILE" "java.util.Set"
      add_import_if_missing "$TO_FILE" "java.util.HashSet"
      add_import_if_missing "$TO_FILE" "com.fasterxml.jackson.annotation.JsonIgnoreProperties"
      add_field_before_last_brace "$TO_FILE" "$TO_BLOCK" "$TO_FIELD_NAME"
      sb_step "Aggiunto @ManyToMany $TO_FIELD_NAME in ${CLEAN_TO}Entity.java"
    fi
    ;;

  *)
    echo "Tipo relazione non supportato: '$TYPE'" >&2
    exit 1
    ;;
esac

# --- Automazione DTO in DTO ---
FROM_DTO_FILE=""
TO_DTO_FILE=""
if [ -d "$DEMO_DIR/common-dto/src/main/java" ]; then
  FROM_DTO_FILE="$(find "$DEMO_DIR/common-dto/src/main/java" -name "${CLEAN_FROM}Dto.java" 2>/dev/null | head -n 1 || true)"
  TO_DTO_FILE="$(find "$DEMO_DIR/common-dto/src/main/java" -name "${CLEAN_TO}Dto.java" 2>/dev/null | head -n 1 || true)"
fi

if [ -n "$FROM_DTO_FILE" ] && [ -n "$TO_DTO_FILE" ] && [ -f "$FROM_DTO_FILE" ] && [ -f "$TO_DTO_FILE" ]; then
  SHOULD_UPDATE_DTO=$DTO
  if [ "$DTO" -eq 0 ] && [ -t 0 ]; then
    echo ""
    echo "Trovati ${CLEAN_FROM}Dto e ${CLEAN_TO}Dto in common-dto."
    printf "  Vuoi aggiornare ${CLEAN_FROM}Dto col pattern DTO in DTO (${CLEAN_TO}Dto annidato) e il Service? [S/n] > "
    read -r ANS
    case "$ANS" in
      [nN]*) SHOULD_UPDATE_DTO=0 ;;
      *) SHOULD_UPDATE_DTO=1 ;;
    esac
  fi

  if [ "$SHOULD_UPDATE_DTO" -eq 1 ]; then
    if ! grep -q "${CLEAN_TO}Dto" "$FROM_DTO_FILE"; then
      python3 -c "
with open('$FROM_DTO_FILE', 'r', encoding='utf-8') as f:
    content = f.read()
idx = content.rfind(')')
if idx > 0:
    before = content[:idx].rstrip()
    after = content[idx:]
    comma = ',' if not before.endswith(('(', ',')) else ''
    new_param = f'{comma}\n    ${CLEAN_TO}Dto ${FROM_FIELD_NAME},\n    Long ${FROM_FIELD_NAME}Id\n'
    with open('$FROM_DTO_FILE', 'w', encoding='utf-8') as f:
        f.write(before + new_param + after)
" 2>/dev/null || true
      sb_step "Aggiornato DTO con ${CLEAN_TO}Dto ${FROM_FIELD_NAME}: $FROM_DTO_FILE"
    fi

    SERVICE_FILE="$MODULE_DIR/src/main/java/$PKG_PATH/service/${CLEAN_FROM}Service.java"
    TO_REPO_FILE="$MODULE_DIR/src/main/java/$PKG_PATH/repository/${CLEAN_TO}Repository.java"
    if [ -f "$SERVICE_FILE" ]; then
      TO_CAMEL="$(to_camel "$CLEAN_TO")"
      REPO_FIELD_NAME="${TO_CAMEL}Repository"
      python3 -c "
with open('$SERVICE_FILE', 'r', encoding='utf-8') as f:
    s = f.read()
if '$REPO_FIELD_NAME' not in s:
    s = s.replace('repository;', 'repository;\n    private final $PKG.repository.${CLEAN_TO}Repository $REPO_FIELD_NAME;')
if 'crea(' in s and 'set${CLEAN_TO}' not in s:
    s = s.replace('entity.setId(null);', 'entity.setId(null);\n        if (nuovo.${FROM_FIELD_NAME}Id() != null) {\n            $REPO_FIELD_NAME.findById(nuovo.${FROM_FIELD_NAME}Id()).ifPresent(entity::set${CLEAN_TO});\n        }')
if 'aggiorna(' in s and 'set${CLEAN_TO}' not in s:
    s = s.replace('return toDto(repository.save(esistente));', 'if (dati.${FROM_FIELD_NAME}Id() != null) {\n            $REPO_FIELD_NAME.findById(dati.${FROM_FIELD_NAME}Id()).ifPresent(esistente::set${CLEAN_TO});\n        }\n        return toDto(repository.save(esistente));')
if 'toDto(' in s and '${FROM_FIELD_NAME}Dto' not in s:
    pascal = '${FROM_FIELD_NAME}'.capitalize()
    mapping = '        ${CLEAN_TO}Dto ${FROM_FIELD_NAME}Dto = $PKG.service.${CLEAN_TO}Service.toDto(entity.get' + pascal + '());\n        Long ${FROM_FIELD_NAME}Id = entity.get' + pascal + '() != null ? entity.get' + pascal + '().getId() : null;\n'
    s = s.replace('if (entity == null) return null;\n', 'if (entity == null) return null;\n' + mapping)
    import re
    s = re.sub(r'(return new ${CLEAN_FROM}Dto\([\s\S]*?entity\.\w+\(\))(\s*\);)', r'\1,\n            ${FROM_FIELD_NAME}Dto,\n            ${FROM_FIELD_NAME}Id\2', s)
with open('$SERVICE_FILE', 'w', encoding='utf-8') as f:
    f.write(s)
" 2>/dev/null || true
      sb_step "Aggiornato Service con mapper DTO in DTO: $SERVICE_FILE"
    fi
  fi
fi

echo ""
echo "Relazione $TYPE configurata con successo!"
