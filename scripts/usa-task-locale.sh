#!/usr/bin/env bash
# Aggiunge al PATH di QUESTA shell la copia di task scaricata da
# "task offline-prep" (in .tools/task), per quando la macchina dell'esame non
# ha task installato, o non e' sul PATH.
#
# Va lanciato con "source" (o ". "), altrimenti il PATH cambierebbe solo nel
# processo figlio che esegue lo script, e sparirebbe subito:
#
#   source scripts/usa-task-locale.sh
#
# L'effetto dura solo questa shell. Per tenerlo per sempre, copia
# .tools/task/task in una cartella gia' sul PATH, o aggiungilo al tuo
# ~/.bashrc (o equivalente).
#
# Questo script non usa "task" per funzionare: e' pensato apposta per il
# momento in cui "task" non c'e' ancora.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TASK_DIR="$REPO_ROOT/.tools/task"
TASK_BIN="$TASK_DIR/task"
[ -e "$TASK_BIN" ] || TASK_BIN="$TASK_DIR/task.exe"

if [ ! -e "$TASK_BIN" ]; then
  echo "Non c'e' una copia locale in .tools/task." >&2
  echo "Procurala con la rete: task offline-prep (o bash scripts/offline.sh --prep)." >&2
  return 1 2>/dev/null || exit 1
fi

case ":$PATH:" in
  *":$TASK_DIR:"*) ;;
  *) export PATH="$TASK_DIR:$PATH" ;;
esac
echo "Aggiunta al PATH di questa shell: $TASK_DIR"
VERSION="$("$TASK_BIN" --version 2>/dev/null)"
[ -n "$VERSION" ] && echo "task pronto: $VERSION"
echo "Per tenerlo oltre questa shell, copia $TASK_BIN dove hai gia' un eseguibile sul PATH."
