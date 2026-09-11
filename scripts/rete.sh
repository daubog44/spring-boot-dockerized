#!/usr/bin/env bash
# Dice quali domini di internet rispondono da questa macchina.
# Equivalente POSIX di scripts/rete.ps1.
#
# All'esame la rete c'e', ma filtrata: una whitelist lascia passare alcuni
# domini (Maven Central si') e altri chissa'. Questo comando bussa ai domini
# che servono al template e dice, per ognuno, se risponde e che cosa fare se
# non risponde. Una risposta qualsiasi, anche un "401", vuol dire che il
# dominio si raggiunge.
#
#   task rete
#   bash scripts/rete.sh --url http://127.0.0.1:9/     (solo per le prove)
set -uo pipefail

TIMEOUT=5
URLS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -Url|--url) URLS+=("$2"); shift 2 ;;
    -TimeoutSeconds|--timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "Argomento non riconosciuto: $1" >&2; exit 1 ;;
  esac
done

# nome|indirizzo|a cosa serve|cosa fare se non risponde
TARGETS=(
  "Maven Central|https://repo.maven.apache.org/maven2/|le dipendenze Maven: moduli nuovi, add-dep, il wrapper|si compila solo con la ~/.m2 della sera prima (task offline)"
  "Docker Hub|https://registry-1.docker.io/v2/|le immagini di base: eclipse-temurin e postgres|le immagini devono essere gia' sul disco (task offline-prep, la sera prima)"
  "Ubuntu|http://archive.ubuntu.com/ubuntu/|curl dentro l'immagine, quando la cache di Docker non ce l'ha|docker compose build regge solo con la cache (task offline-prep)"
  "GitHub|https://github.com/|git clone e le release del template|il template arriva dalla chiavetta"
  "VS Code Marketplace|https://marketplace.visualstudio.com/|le estensioni di VS Code|valgono solo le estensioni gia' installate"
)
if [ "${#URLS[@]}" -gt 0 ]; then
  TARGETS=()
  for u in "${URLS[@]}"; do TARGETS+=("$u|$u|indirizzo di prova|non raggiungibile"); done
fi

echo ""
echo "LA RETE, DA QUESTA MACCHINA"
echo ""

if ! command -v curl >/dev/null 2>&1; then
  echo "  Manca curl: non posso provare la rete da qui."
  echo ""
  exit 0
fi

BLOCKED=()
for t in "${TARGETS[@]}"; do
  IFS='|' read -r name url serve seno <<EOF
$t
EOF
  # 000 = nessuna risposta: dominio bloccato, nome che non si risolve, tempo scaduto.
  code="$(curl -s -o /dev/null -I -m "$TIMEOUT" -w '%{http_code}' "$url" 2>/dev/null)"
  if [ -n "$code" ] && [ "$code" != "000" ]; then
    printf '  %-21s%-15s%s\n' "$name" "risponde" "$serve"
  else
    printf '  %-21s%-15s%s\n' "$name" "NON risponde" "$serve"
    BLOCKED+=("$name|$seno")
  fi
done

echo ""
if [ "${#BLOCKED[@]}" -eq 0 ]; then
  echo "Passa tutto: si lavora come a casa."
else
  echo "Quello che non passa, e cosa vuol dire:"
  for b in "${BLOCKED[@]}"; do
    printf '  %-21s%s\n' "${b%%|*}" "${b#*|}"
  done
fi
echo ""
echo "  Dietro un proxy? Maven lo legge da ~/.m2/settings.xml, Docker dalle"
echo "  impostazioni di Docker Desktop; curl dalle variabili https_proxy."
echo ""
exit 0
