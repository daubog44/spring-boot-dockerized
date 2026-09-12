#!/usr/bin/env bash
# Genera l'entity, il repository, il service e il controller per una tabella,
# dentro un modulo che esiste gia'. Equivalente POSIX di scripts/new-entity.ps1.
#
#   task new-entity SERVICE=catalogo-service NAME=Libro FIELDS=titolo:string(150):required,isbn:string(13):unique
#
# Quello che NON genera, apposta: le relazioni fra entity (@ManyToOne,
# @OneToMany...) e le regole della traccia nel service. Sono decisioni tue,
# non boilerplate -- vedi la lezione 8 del corso (task learn).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_DIR="$REPO_ROOT/demo"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

SERVICE=""
NAME=""
FIELDS=""
TABLE=""
DTO=0
while [ $# -gt 0 ]; do
  case "$1" in
    -Service|--service) SERVICE="$2"; shift 2 ;;
    -Name|--name) NAME="$2"; shift 2 ;;
    -Fields|--fields) FIELDS="$2"; shift 2 ;;
    -Table|--table) TABLE="$2"; shift 2 ;;
    -Dto|--dto) DTO=1; shift ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

USAGE="Uso: task new-entity SERVICE=<modulo> NAME=<Entita> FIELDS=<campo:tipo:modificatore,...>"
{ [ -n "$SERVICE" ] && [ -n "$NAME" ]; } || { echo "$USAGE" >&2; exit 1; }
if ! printf '%s' "$NAME" | grep -qE '^[A-Z][a-zA-Z0-9]*$'; then
  echo "Nome non valido: '$NAME'. Usa il PascalCase, come lo scriveresti in Java: Libro, RigaOrdine." >&2
  exit 1
fi

MODULE_DIR="$DEMO_DIR/$SERVICE"
if [ ! -f "$MODULE_DIR/pom.xml" ]; then
  echo "Non trovo il modulo '$SERVICE' in demo/. Crealo prima con task new-service NAME=$SERVICE." >&2
  exit 1
fi
if ! grep -q 'spring-boot-starter-data-jpa' "$MODULE_DIR/pom.xml"; then
  echo "'$SERVICE' non ha un database (creato con NODB=1 o UI=1): niente JPA, niente entity." >&2
  echo "Rifallo senza NODB, o aggiungi a mano spring-boot-starter-data-jpa, h2, postgresql e validation al suo pom.xml." >&2
  exit 1
fi

PACKAGE="$(base_package "$DEMO_DIR").$(printf '%s' "$SERVICE" | tr -cd 'a-zA-Z0-9')"
PACKAGE_PATH="$(printf '%s' "$PACKAGE" | tr '.' '/')"
JAVA_DIR="$MODULE_DIR/src/main/java/$PACKAGE_PATH"
ENTITY_DIR="$JAVA_DIR/entity"
REPO_DIR="$JAVA_DIR/repository"
SERVICE_DIR="$JAVA_DIR/service"
CONTROLLER_DIR="$JAVA_DIR/controller"
mkdir -p "$ENTITY_DIR" "$REPO_DIR" "$SERVICE_DIR" "$CONTROLLER_DIR"

ENTITY_FILE="$ENTITY_DIR/${NAME}Entity.java"
if [ -e "$ENTITY_FILE" ]; then
  echo "C'e' gia' $ENTITY_FILE. Cancellalo prima, o scegli un altro nome." >&2
  exit 1
fi

# "${arr[*]}" con IFS a due caratteri unisce solo sul PRIMO: IFS=', ' da'
# "a,b", non "a, b". La virgola-spazio va costruita a mano.
join_comma_space() {
  local out="" first=1
  for item in "$@"; do
    if [ "$first" = "1" ]; then out="$item"; first=0; else out="$out, $item"; fi
  done
  printf '%s' "$out"
}

to_snake_case() {
  # RigaOrdine -> riga_ordine
  printf '%s' "$1" | sed -E 's/([A-Z])/_\1/g; s/^_//' | tr 'A-Z' 'a-z'
}
pascal_field() {
  # annoPubblicazione -> AnnoPubblicazione
  local f="$1"
  printf '%s%s' "$(printf '%s' "${f:0:1}" | tr 'a-z' 'A-Z')" "${f:1}"
}

TABLE_NAME="${TABLE:-$(to_snake_case "$NAME")}"
ROUTE_BASE="$(printf '%s' "$TABLE_NAME" | tr '_' '-')"

# --- Interpretazione di FIELDS -------------------------------------------------

# Un campo: nome:tipo[:modificatore]*. Il tipo puo' avere parentesi
# (string(150), enum(A|B|C)): dentro non ci sono mai virgole, quindi spezzare
# FIELDS sulla virgola resta sicuro.
FIELD_BLOCKS=()
SETTER_LINES=()
UNIQUE_FIELDS=()
FIELD_NAMES=()
FIELD_PASCALS=()
USES_BIGDECIMAL=0
USES_LOCALDATE=0
USES_LOCALDATETIME=0
ENUM_FILES=()

if [ -n "$FIELDS" ]; then
  IFS=',' read -ra RAW_FIELDS <<<"$FIELDS"
  for raw in "${RAW_FIELDS[@]}"; do
    raw="$(printf '%s' "$raw" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [ -z "$raw" ] && continue
    IFS=':' read -ra TOK <<<"$raw"
    if [ "${#TOK[@]}" -lt 2 ]; then
      echo "Campo mal scritto: '$raw'. Serve almeno nome:tipo, es. titolo:string(150)." >&2
      exit 1
    fi
    FIELD_NAME="${TOK[0]}"
    if ! printf '%s' "$FIELD_NAME" | grep -qE '^[a-z][a-zA-Z0-9]*$'; then
      echo "Nome campo non valido: '$FIELD_NAME'. Usa il camelCase, come in Java: annoPubblicazione." >&2
      exit 1
    fi
    TYPE_TOKEN="${TOK[1]}"

    REQUIRED=0
    UNIQUE=0
    MIN_VAL=""
    MAX_VAL=""
    if [ "${#TOK[@]}" -gt 2 ]; then
      for ((mi = 2; mi < ${#TOK[@]}; mi++)); do
        MOD="${TOK[$mi]}"
        case "$MOD" in
          required) REQUIRED=1 ;;
          unique) UNIQUE=1 ;;
          min\(*\))
            MIN_VAL="$(printf '%s' "$MOD" | sed -E 's/^min\((-?[0-9]+)\)$/\1/')"
            [ "$MIN_VAL" != "$MOD" ] || { echo "Modificatore non valido: '$MOD' (campo '$FIELD_NAME')." >&2; exit 1; }
            ;;
          max\(*\))
            MAX_VAL="$(printf '%s' "$MOD" | sed -E 's/^max\((-?[0-9]+)\)$/\1/')"
            [ "$MAX_VAL" != "$MOD" ] || { echo "Modificatore non valido: '$MOD' (campo '$FIELD_NAME')." >&2; exit 1; }
            ;;
          *)
            echo "Modificatore non riconosciuto: '$MOD' (campo '$FIELD_NAME'). Validi: required, unique, min(N), max(N)." >&2
            exit 1
            ;;
        esac
      done
    fi

    JAVA_TYPE=""
    ENUM_NAME=""
    LENGTH=""
    VALIDATION_LINES=()

    if [ "$TYPE_TOKEN" = "string" ]; then
      JAVA_TYPE="String"
    elif [[ "$TYPE_TOKEN" =~ ^string\(([0-9]+)\)$ ]]; then
      JAVA_TYPE="String"; LENGTH="${BASH_REMATCH[1]}"
    elif [ "$TYPE_TOKEN" = "text" ]; then
      JAVA_TYPE="String"; VALIDATION_LINES+=("@Lob")
    elif [ "$TYPE_TOKEN" = "int" ]; then
      JAVA_TYPE="Integer"
    elif [ "$TYPE_TOKEN" = "long" ]; then
      JAVA_TYPE="Long"
    elif [ "$TYPE_TOKEN" = "decimal" ]; then
      JAVA_TYPE="BigDecimal"; USES_BIGDECIMAL=1
    elif [ "$TYPE_TOKEN" = "bool" ]; then
      JAVA_TYPE="Boolean"
    elif [ "$TYPE_TOKEN" = "date" ]; then
      JAVA_TYPE="LocalDate"; USES_LOCALDATE=1
    elif [ "$TYPE_TOKEN" = "datetime" ]; then
      JAVA_TYPE="LocalDateTime"; USES_LOCALDATETIME=1
    elif [ "$TYPE_TOKEN" = "email" ]; then
      JAVA_TYPE="String"; LENGTH="120"; VALIDATION_LINES+=("@Email")
    elif [[ "$TYPE_TOKEN" =~ ^enum\(([A-Za-z0-9_|]+)\)$ ]]; then
      RAW_VALUES="${BASH_REMATCH[1]}"
      IFS='|' read -ra EV <<<"$RAW_VALUES"
      if [ "${#EV[@]}" -lt 2 ]; then
        echo "L'enum del campo '$FIELD_NAME' vuole almeno due valori: enum(A|B)." >&2
        exit 1
      fi
      UPPER_VALUES=()
      LONGEST=0
      for v in "${EV[@]}"; do
        uv="$(printf '%s' "$v" | tr 'a-z' 'A-Z')"
        UPPER_VALUES+=("$uv")
        [ "${#uv}" -gt "$LONGEST" ] && LONGEST="${#uv}"
      done
      ENUM_NAME="$(pascal_field "$FIELD_NAME")"
      JAVA_TYPE="$ENUM_NAME"
      LENGTH=20
      [ "$LONGEST" -gt 20 ] && LENGTH="$LONGEST"

      ENUM_BODY="$(IFS=$'\n'; printf '%s,\n    ' "${UPPER_VALUES[@]}")"
      ENUM_BODY="${ENUM_BODY%,*}"
      cat >"$ENTITY_DIR/$ENUM_NAME.java" <<EOF
package $PACKAGE.entity;

public enum $ENUM_NAME {
    $ENUM_BODY
}
EOF
      ENUM_FILES+=("demo/$SERVICE/src/main/java/$PACKAGE_PATH/entity/$ENUM_NAME.java")
      VALIDATION_LINES+=("@Enumerated(EnumType.STRING)")
    else
      echo "Tipo non riconosciuto per '$FIELD_NAME': '$TYPE_TOKEN'. Vedi task --summary new-entity." >&2
      exit 1
    fi

    COLUMN_ATTRS=()
    if [ "$REQUIRED" = "1" ]; then
      COLUMN_ATTRS+=("nullable = false")
      if [ "$JAVA_TYPE" = "String" ] && [ -z "$ENUM_NAME" ]; then VALIDATION_LINES+=("@NotBlank")
      else VALIDATION_LINES+=("@NotNull"); fi
    fi
    if [ "$UNIQUE" = "1" ]; then
      COLUMN_ATTRS+=("unique = true")
      UNIQUE_FIELDS+=("$FIELD_NAME")
    fi
    if [ -n "$LENGTH" ]; then COLUMN_ATTRS+=("length = $LENGTH"); fi
    if [ -n "$MIN_VAL" ]; then VALIDATION_LINES+=("@Min($MIN_VAL)"); fi
    if [ -n "$MAX_VAL" ]; then VALIDATION_LINES+=("@Max($MAX_VAL)"); fi

    BLOCK=""
    for v in "${VALIDATION_LINES[@]}"; do BLOCK="${BLOCK}    $v"$'\n'; done
    if [ "${#COLUMN_ATTRS[@]}" -gt 0 ]; then
      COLUMN_JOINED="$(join_comma_space "${COLUMN_ATTRS[@]}")"
      BLOCK="${BLOCK}    @Column($COLUMN_JOINED)"$'\n'
    fi
    BLOCK="${BLOCK}    private $JAVA_TYPE $FIELD_NAME;"
    FIELD_BLOCKS+=("$BLOCK")

    PASCAL="$(pascal_field "$FIELD_NAME")"
    FIELD_NAMES+=("$FIELD_NAME")
    FIELD_PASCALS+=("$PASCAL")
    SETTER_LINES+=("        esistente.set$PASCAL(dati.get$PASCAL());")
  done
fi

for f in "${ENUM_FILES[@]}"; do echo "  $f"; done

# --- 2. L'entity ----------------------------------------------------------

ENTITY_FIELDS=""
if [ "${#FIELD_BLOCKS[@]}" -gt 0 ]; then
  ENTITY_FIELDS=$'\n'
  LAST=$((${#FIELD_BLOCKS[@]} - 1))
  for i in "${!FIELD_BLOCKS[@]}"; do
    ENTITY_FIELDS="${ENTITY_FIELDS}${FIELD_BLOCKS[$i]}"
    # Una riga vuota fra un campo e l'altro, ma non dopo l'ultimo: quella
    # la mette gia' l'a-capo del blocco ${ENTITY_FIELDS} nel qui-documento.
    [ "$i" -lt "$LAST" ] && ENTITY_FIELDS="${ENTITY_FIELDS}"$'\n\n'
  done
fi

EXTRA_IMPORTS=""
[ "$USES_BIGDECIMAL" = "1" ] && EXTRA_IMPORTS="${EXTRA_IMPORTS}import java.math.BigDecimal;"$'\n'
[ "$USES_LOCALDATE" = "1" ] && EXTRA_IMPORTS="${EXTRA_IMPORTS}import java.time.LocalDate;"$'\n'
[ "$USES_LOCALDATETIME" = "1" ] && EXTRA_IMPORTS="${EXTRA_IMPORTS}import java.time.LocalDateTime;"$'\n'

cat >"$ENTITY_FILE" <<EOF
package $PACKAGE.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
${EXTRA_IMPORTS}
// Generata da task new-entity: aggiungi qui le relazioni (@ManyToOne,
// @OneToMany...) con altre entity DI QUESTO STESSO SERVIZIO. Con un altro
// servizio niente relazione: solo un id (Long) e una chiamata Feign, vedi
// la lezione 8 e la 10 del corso (task learn).
@Entity
@Table(name = "$TABLE_NAME")
@Getter
@Setter
@NoArgsConstructor
public class ${NAME}Entity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
${ENTITY_FIELDS}
}
EOF
echo "  demo/$SERVICE/src/main/java/$PACKAGE_PATH/entity/${NAME}Entity.java"

# --- 3. Il repository -------------------------------------------------------

cat >"$REPO_DIR/${NAME}Repository.java" <<EOF
package $PACKAGE.repository;

import $PACKAGE.entity.${NAME}Entity;
import org.springframework.data.jpa.repository.JpaRepository;

// Vuoto apposta: JpaRepository da' gia' findAll, findById, save, deleteById,
// existsById, count. Le query della tua traccia le aggiungi qui, dal nome
// del metodo (findByGenere, existsByIsbn...) o con @Query -- vedi la
// lezione 8 del corso (task learn) per il catalogo completo.
public interface ${NAME}Repository extends JpaRepository<${NAME}Entity, Long> {
}
EOF
echo "  demo/$SERVICE/src/main/java/$PACKAGE_PATH/repository/${NAME}Repository.java"

# --- 4. Service e Controller --------------------------------------------------

BASE_PKG="$(base_package "$DEMO_DIR")"
DTO_NAME="${NAME}Dto"

if [ "$DTO" = "1" ]; then
  DTO_FIELDS="$FIELDS"
  if ! printf '%s' "$FIELDS" | grep -qE '\bid:long\b'; then
    if [ -n "$FIELDS" ]; then
      DTO_FIELDS="id:long,$FIELDS"
    else
      DTO_FIELDS="id:long"
    fi
  fi
  bash "$SCRIPT_DIR/new-dto.sh" --name "$NAME" --fields "$DTO_FIELDS" --service "common-dto" > /dev/null

  TO_DTO_ARGS=""
  for p in "${FIELD_PASCALS[@]}"; do
    TO_DTO_ARGS="${TO_DTO_ARGS},"$'\n'"            entity.get${p}()"
  done

  TO_ENTITY_SETTERS=""
  for i in "${!FIELD_NAMES[@]}"; do
    fn="${FIELD_NAMES[$i]}"
    fp="${FIELD_PASCALS[$i]}"
    TO_ENTITY_SETTERS="${TO_ENTITY_SETTERS}        entity.set${fp}(dto.${fn}());"$'\n'
  done
  [ -z "$TO_ENTITY_SETTERS" ] && TO_ENTITY_SETTERS="        // Nessun campo aggiuntivo"$'\n'

  SETTER_LINES_FROM_DTO=""
  for i in "${!FIELD_NAMES[@]}"; do
    fn="${FIELD_NAMES[$i]}"
    fp="${FIELD_PASCALS[$i]}"
    SETTER_LINES_FROM_DTO="${SETTER_LINES_FROM_DTO}        esistente.set${fp}(dati.${fn}());"$'\n'
  done
  [ -z "$SETTER_LINES_FROM_DTO" ] && SETTER_LINES_FROM_DTO="        // Nessun campo da aggiornare"$'\n'
  SETTER_LINES_FROM_DTO="${SETTER_LINES_FROM_DTO%$'\n'}"

  cat >"$SERVICE_DIR/${NAME}Service.java" <<EOF
package $PACKAGE.service;

import $PACKAGE.entity.${NAME}Entity;
import $PACKAGE.repository.${NAME}Repository;
import $BASE_PKG.common.dto.$DTO_NAME;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ${NAME}Service {

    private final ${NAME}Repository repository;

    public List<$DTO_NAME> elenco() {
        return repository.findAll().stream().map(${NAME}Service::toDto).toList();
    }

    public $DTO_NAME trova(Long id) {
        return toDto(trovaEntity(id));
    }

    public $DTO_NAME crea($DTO_NAME nuovo) {
        ${NAME}Entity entity = toEntity(nuovo);
        entity.setId(null);
        return toDto(repository.save(entity));
    }

    public $DTO_NAME aggiorna(Long id, $DTO_NAME dati) {
        ${NAME}Entity esistente = trovaEntity(id);
$SETTER_LINES_FROM_DTO
        return toDto(repository.save(esistente));
    }

    public void elimina(Long id) {
        trovaEntity(id);
        repository.deleteById(id);
    }

    private ${NAME}Entity trovaEntity(Long id) {
        return repository.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "$NAME " + id + " non trovato"));
    }

    // --- Mapper Entity <-> DTO ---

    public static $DTO_NAME toDto(${NAME}Entity entity) {
        if (entity == null) return null;
        return new $DTO_NAME(
            entity.getId()${TO_DTO_ARGS}
        );
    }

    public static ${NAME}Entity toEntity($DTO_NAME dto) {
        if (dto == null) return null;
        ${NAME}Entity entity = new ${NAME}Entity();
        entity.setId(dto.id());
${TO_ENTITY_SETTERS}        return entity;
    }
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PACKAGE_PATH/service/${NAME}Service.java"

  cat >"$CONTROLLER_DIR/${NAME}Controller.java" <<EOF
package $PACKAGE.controller;

import $BASE_PKG.common.dto.$DTO_NAME;
import $PACKAGE.service.${NAME}Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "$NAME", description = "CRUD per $NAME basato su DTO")
@RestController
@RequestMapping("/api/$ROUTE_BASE")
@RequiredArgsConstructor
public class ${NAME}Controller {

    private final ${NAME}Service service;

    @Operation(summary = "Tutti/e")
    @GetMapping
    public List<$DTO_NAME> elenco() {
        return service.elenco();
    }

    @Operation(summary = "Per id (404 se non c'e')")
    @GetMapping("/{id}")
    public $DTO_NAME perId(@PathVariable Long id) {
        return service.trova(id);
    }

    @Operation(summary = "Crea")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public $DTO_NAME crea(@Valid @RequestBody $DTO_NAME nuovo) {
        return service.crea(nuovo);
    }

    @Operation(summary = "Aggiorna (404 se non c'e')")
    @PutMapping("/{id}")
    public $DTO_NAME aggiorna(@PathVariable Long id, @Valid @RequestBody $DTO_NAME dati) {
        return service.aggiorna(id, dati);
    }

    @Operation(summary = "Elimina (404 se non c'e')")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void elimina(@PathVariable Long id) {
        service.elimina(id);
    }
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PACKAGE_PATH/controller/${NAME}Controller.java"
else
  SETTER_BLOCK="        // Nessun campo da FIELDS=: aggiungi qui i tuoi set..."
  if [ "${#SETTER_LINES[@]}" -gt 0 ]; then
    SETTER_BLOCK="$(printf '%s\n' "${SETTER_LINES[@]}")"
    SETTER_BLOCK="${SETTER_BLOCK%$'\n'}"
  fi

  cat >"$SERVICE_DIR/${NAME}Service.java" <<EOF
package $PACKAGE.service;

import $PACKAGE.entity.${NAME}Entity;
import $PACKAGE.repository.${NAME}Repository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ${NAME}Service {

    private final ${NAME}Repository repository;

    public List<${NAME}Entity> elenco() {
        return repository.findAll();
    }

    public ${NAME}Entity trova(Long id) {
        return repository.findById(id).orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "$NAME " + id + " non trovato"));
    }

    public ${NAME}Entity crea(${NAME}Entity nuovo) {
        return repository.save(nuovo);
    }

    // Sovrascrive tutti i campi: per un aggiornamento parziale, togli le
    // righe dei campi che non vuoi toccare.
    public ${NAME}Entity aggiorna(Long id, ${NAME}Entity dati) {
        ${NAME}Entity esistente = trova(id);
$SETTER_BLOCK
        return repository.save(esistente);
    }

    public void elimina(Long id) {
        trova(id); // 404 prima di provare a cancellare, non un 500 a caso
        repository.deleteById(id);
    }
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PACKAGE_PATH/service/${NAME}Service.java"

  cat >"$CONTROLLER_DIR/${NAME}Controller.java" <<EOF
package $PACKAGE.controller;

import $PACKAGE.entity.${NAME}Entity;
import $PACKAGE.service.${NAME}Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// CRUD generato da task new-entity: aggiungi qui le regole della tua
// traccia. Se questi dati li consuma anche un altro servizio (Feign), o non
// vuoi esporre tutti i campi cosi' come sono in tabella, usa DTO=1 oppure sostituisci
// ${NAME}Entity con un DTO tuo -- vedi la lezione 9 ("fuori dal servizio
// esce il DTO, mai l'entity") e la lezione 4 su common-dto.
@Tag(name = "$NAME", description = "Generato da new-entity: descrivilo meglio")
@RestController
@RequestMapping("/api/$ROUTE_BASE")
@RequiredArgsConstructor
public class ${NAME}Controller {

    private final ${NAME}Service service;

    @Operation(summary = "Tutti/e")
    @GetMapping
    public List<${NAME}Entity> elenco() {
        return service.elenco();
    }

    @Operation(summary = "Per id (404 se non c'e')")
    @GetMapping("/{id}")
    public ${NAME}Entity perId(@PathVariable Long id) {
        return service.trova(id);
    }

    @Operation(summary = "Crea")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ${NAME}Entity crea(@Valid @RequestBody ${NAME}Entity nuovo) {
        return service.crea(nuovo);
    }

    @Operation(summary = "Aggiorna (404 se non c'e')")
    @PutMapping("/{id}")
    public ${NAME}Entity aggiorna(@PathVariable Long id, @Valid @RequestBody ${NAME}Entity dati) {
        return service.aggiorna(id, dati);
    }

    @Operation(summary = "Elimina (404 se non c'e')")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void elimina(@PathVariable Long id) {
        service.elimina(id);
    }
}
EOF
  echo "  demo/$SERVICE/src/main/java/$PACKAGE_PATH/controller/${NAME}Controller.java"
fi

# --- Riepilogo -----------------------------------------------------------------

echo ""
echo "Fatto: ${NAME}Entity in tabella '$TABLE_NAME', su /api/$ROUTE_BASE."
if [ "${#UNIQUE_FIELDS[@]}" -gt 0 ]; then
  JOINED_UNIQUE="$(join_comma_space "${UNIQUE_FIELDS[@]}")"
  echo "  'unique' su $JOINED_UNIQUE e' solo un vincolo del database: violarlo da' un 500"
  echo "  finche' non lo controlli tu nel service (es. un existsBy... prima del save)."
fi
echo "  Restano da aggiungere a mano: le relazioni con altre entity, e le regole della traccia."
echo ""
