#!/usr/bin/env bash
# Genera o aggiorna allegato.md e compila l'anteprima di ALLEGATO-TECNICO.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/scaffold-lib.sh
. "$SCRIPT_DIR/scaffold-lib.sh"

REPO_ROOT="$(get_scaffold_repo_root)"
DEMO_DIR="$REPO_ROOT/demo"
DEV_SH="$SCRIPT_DIR/dev.sh"
DEV_PS1="$SCRIPT_DIR/dev.ps1"
ALLEGATO_FILE="$REPO_ROOT/allegato.md"

NOME="CANDIDATO"
OUT_DIR="$REPO_ROOT"

for arg in "$@"; do
  case "$arg" in
    NOME=*|nome=*) NOME="${arg#*=}" ;;
    OUTDIR=*|outdir=*) OUT_DIR="${arg#*=}" ;;
  esac
done

echo ""
echo -e "\033[36m==> Generazione e verifica Allegato Tecnico\033[0m"

# 1. Inizializzazione allegato.md se mancante
if [ ! -f "$ALLEGATO_FILE" ]; then
  cat << 'EOF' > "$ALLEGATO_FILE"
# Allegato tecnico: le parti scritte da te

task allegato e task consegna prendono ogni sezione di questo file e la inseriscono
in ALLEGATO-TECNICO.md, accanto a quanto ricavato in automatico dal codice.

## Analisi

[Descrivi brevemente il contesto, il problema e gli obiettivi del progetto.]

## Algoritmo

[Descrivi la logica algoritmica implementata, passaggi e complessità temporale.]

## Domanda A

[Inserisci qui la risposta alla prima domanda teorica.]

## Domanda B

[Inserisci qui la risposta alla seconda domanda teorica.]
EOF
  echo "  creato $ALLEGATO_FILE"
fi

# 2. Schema DB
SCHEMA_TEXT=""
if [ -f "$SCRIPT_DIR/db-schema.sh" ]; then
  SCHEMA_TEXT="$(bash "$SCRIPT_DIR/db-schema.sh" 2>/dev/null || echo "Nessuna entità persistente rilevata.")"
fi
echo "$SCHEMA_TEXT" > "$OUT_DIR/SCHEMA-DATABASE.md"
echo "  generato SCHEMA-DATABASE.md"

# 3. Compilazione documento base
TODAY="$(date +'%d/%m/%Y')"
DOC_OUT="$OUT_DIR/ALLEGATO-TECNICO.md"

cat << EOF > "$DOC_OUT"
# Allegato Tecnico di Progetto

Candidato: **$NOME**  
Data: $TODAY  

---

## 1. Analisi del problema e contesto applicativo

$(sed -n '/^## Analisi/,/^##/p' "$ALLEGATO_FILE" | grep -v '^##' | sed '/^$/N;/^\n$/D' || echo "[Da compilare]")

## 2. Architettura della soluzione e ripartizione moduli

Architettura a microservizi Spring Boot, con service discovery Netflix Eureka e
chiamate inter-servizio tramite OpenFeign.

## 3. Schema concettuale e logico della base dati

$SCHEMA_TEXT

## 4. Descrizione dell'algoritmo e complessità

$(sed -n '/^## Algoritmo/,/^##/p' "$ALLEGATO_FILE" | grep -v '^##' | sed '/^$/N;/^\n$/D' || echo "[Da compilare]")

## 5. Istruzioni per il test della soluzione

Esegui con Docker Compose:
\`\`\`bash
docker compose up -d --build
\`\`\`

---

## 6. Risposte alle Domande Teoriche

### Domanda A
$(sed -n '/^## Domanda A/,/^##/p' "$ALLEGATO_FILE" | grep -v '^##' | sed '/^$/N;/^\n$/D' || echo "[Da compilare]")

### Domanda B
$(sed -n '/^## Domanda B/,/^##/p' "$ALLEGATO_FILE" | grep -v '^##' | sed '/^$/N;/^\n$/D' || echo "[Da compilare]")

EOF

echo "  compilato ALLEGATO-TECNICO.md"
echo ""
echo -e "\033[32mAllegato Tecnico aggiornato in $DOC_OUT\033[0m"
echo ""
