#!/usr/bin/env bash
# Funzioni condivise dagli script di sviluppo (dev, dev-down, logs, status).
# Equivalente POSIX di scripts/dev-lib.ps1: la gestione delle porte e l'arresto
# dei servizi stanno qui, cosi' l'avvio e l'arresto non possono divergere.

# Porte dello stack, anche quando .dev-logs/dev.ports non esiste piu'.
DEV_DEFAULT_PORTS="8761 8081 8082 8083 8080"

dev_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

dev_log_dir() {
  echo "$(dev_repo_root)/.dev-logs"
}

# Un progetto Docker Compose per copia del template, col nome della cartella
# del repository (come fa il Taskfile): con quello di default, demo, due copie
# si prendevano container e volume del database a vicenda.
if [ -z "${COMPOSE_PROJECT_NAME:-}" ]; then
  COMPOSE_PROJECT_NAME="$(basename "$(dev_repo_root)" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9_-]+/-/g; s/^[^a-z0-9]+//')"
  export COMPOSE_PROJECT_NAME
fi
# Anche un `docker compose` scritto a mano dentro demo/ (le guide lo usano per
# fermare un servizio o leggerne i log) deve trovare lo stesso progetto:
# Compose legge il nome da demo/.env, che git ignora.
_compose_env="$(dev_repo_root)/demo/.env"
if [ -n "$COMPOSE_PROJECT_NAME" ] && [ -d "$(dirname "$_compose_env")" ] &&
  ! grep -qx "COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME" "$_compose_env" 2>/dev/null; then
  { echo "COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME"
    grep -v '^[[:space:]]*COMPOSE_PROJECT_NAME[[:space:]]*=' "$_compose_env" 2>/dev/null || true
  } >"$_compose_env.tmp" && mv "$_compose_env.tmp" "$_compose_env"
fi
unset _compose_env

# Tutte le porte da controllare: le fisse piu' quelle dell'ultimo avvio
# (che possono differire se e' stato passato --ui-port).
dev_ports() {
  local log_dir="$1"
  local ports="$DEV_DEFAULT_PORTS"
  if [ -f "$log_dir/dev.ports" ]; then
    ports="$ports $(tr '\n' ' ' <"$log_dir/dev.ports")"
  fi
  echo "$ports" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -u
}

port_pids() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null
  fi
}

port_in_use() {
  local port="$1"
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$port" >/dev/null 2>&1
  else
    (exec 3<>"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1
  fi
}

process_name() {
  ps -p "$1" -o comm= 2>/dev/null | tr -d ' '
}

# Chiude l'intero albero: mvnw ha maven come figlio e la JVM
# dell'applicazione come nipote, altrimenti resterebbe orfana in ascolto.
kill_tree() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    kill_tree "$child"
  done
  kill -TERM "$pid" >/dev/null 2>&1 || true
}

wait_for_port() {
  local port="$1" timeout="${2:-120}" elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    if port_in_use "$port"; then return 0; fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

# Ferma i container di altri progetti Compose che tengono una porta dello stack:
# un'altra copia del template, o questa stessa di prima che ogni copia avesse il
# suo progetto. Fermati, non cancellati: i loro dati restano. Quelli di questo
# progetto non si toccano.
# Uso: stop_foreign_containers <porta> [keep_foreign]
stop_foreign_containers() {
  local port="$1" keep="${2:-}" cid cname
  command -v docker >/dev/null 2>&1 || return 0
  while read -r cid cname; do
    [ -z "${cid:-}" ] && continue
    if [ -n "${COMPOSE_PROJECT_NAME:-}" ]; then
      case "$cname" in "$COMPOSE_PROJECT_NAME"-*) continue ;; esac
    fi
    if [ -n "$keep" ]; then
      echo "  porta $port tenuta dal container $cname, di un altro progetto: lasciato acceso." >&2
    else
      echo "  fermo il container $cname, di un altro progetto, che teneva la porta $port" >&2
      docker stop "$cid" >/dev/null 2>&1 || true
    fi
  done < <(docker ps --filter "publish=$port" --format '{{.ID}} {{.Names}}' 2>/dev/null)
}

# Libera davvero le porte dello stack: termina i nostri processi java, spegne i
# container dell'esame e chiude le applicazioni estranee rimaste in ascolto.
# Restano intoccati i processi di sistema e l'infrastruttura di Docker.
# Uso: stop_dev_stack <log_dir> [quiet] [repo_root] [keep_foreign] [extra_ports]
# extra_ports: porte della configurazione di chi chiama (dev.sh passa le sue),
# cosi' cambiarle in un posto solo basta anche per la pulizia.
# Stampa il numero di processi fermati sullo stdout.
stop_dev_stack() {
  local log_dir="$1" quiet="${2:-}" repo_root="${3:-}" keep_foreign="${4:-}" extra_ports="${5:-}"
  local stopped=0 pid name port

  if [ -f "$log_dir/dev.pids" ]; then
    while read -r pid name; do
      [ -z "${pid:-}" ] && continue
      if kill -0 "$pid" >/dev/null 2>&1; then
        [ -z "$quiet" ] && echo "  fermo $name (PID $pid)" >&2
        kill_tree "$pid"
        stopped=$((stopped + 1))
      fi
    done <"$log_dir/dev.pids"
    rm -f "$log_dir/dev.pids"
  fi

  # Tutto quello che e' rimasto in ascolto sulle porte dello stack: i nostri java
  # di un avvio precedente, i container dell'esame, le applicazioni estranee.
  # L'obiettivo e' che dopo questa funzione le porte siano libere.
  local docker_holds_ports=0 pname all_ports
  all_ports="$(printf '%s\n%s\n' "$(dev_ports "$log_dir")" "$(echo "$extra_ports" | tr ' ' '\n')" | grep -E '^[0-9]+$' | sort -u)"
  for port in $all_ports; do
    for pid in $(port_pids "$port"); do
      pname="$(process_name "$pid")"
      case "$pname" in
        java*)
          [ -z "$quiet" ] && echo "  fermo java (PID $pid) sulla porta $port" >&2
          kill -TERM "$pid" >/dev/null 2>&1 || true
          stopped=$((stopped + 1))
          ;;
        docker*|dockerd|containerd|com.docker*|vpnkit)
          # Nostri quanto i java, ma vanno spenti dal loro gestore.
          docker_holds_ports=1
          ;;
        init|systemd|launchd)
          [ -z "$quiet" ] && echo "  porta $port occupata da $pname (PID $pid): processo di sistema, non lo tocco." >&2
          ;;
        *)
          if [ -n "$keep_foreign" ]; then
            [ -z "$quiet" ] && echo "  porta $port occupata da $pname (PID $pid), estraneo allo stack: lasciato in esecuzione." >&2
          else
            echo "  chiudo $pname (PID $pid), estraneo allo stack, che teneva la porta $port" >&2
            kill -TERM "$pid" >/dev/null 2>&1 || true
            stopped=$((stopped + 1))
          fi
          ;;
      esac
    done
  done

  # I container dell'esame. `down` e non `down -v`: i dati del database restano.
  if [ "$docker_holds_ports" -eq 1 ] && [ -n "$repo_root" ]; then
    [ -z "$quiet" ] && echo "  fermo i container dell'esame, che tenevano le porte" >&2
    (cd "$repo_root/demo" && docker compose down --remove-orphans >/dev/null 2>&1) || \
      echo "  (docker compose non raggiungibile)" >&2
    stopped=$((stopped + 1))
    # Un container di un'altra copia del template, o di prima che ogni copia
    # avesse il suo progetto Compose, puo' tenere ancora le porte.
    for port in $all_ports; do
      stop_foreign_containers "$port" "$keep_foreign"
    done
  fi

  # Le porte in chiusura restano qualche istante in TIME_WAIT.
  [ "$stopped" -gt 0 ] && sleep 2
  echo "$stopped"
}
