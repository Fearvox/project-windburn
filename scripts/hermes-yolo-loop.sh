#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

HOST="${HERMES_DROPLET_HOST:-137.184.104.26}"
REMOTE_USER="${WINDBURN_REMOTE_USER:-root}"
IDENTITY="${WINDBURN_SSH_IDENTITY:-$HOME/.ssh/id_ed25519}"
SSH_TIMEOUT="${WINDBURN_SSH_TIMEOUT:-12}"
SESSION="${HERMES_TMUX_SESSION:-windburn-hermes-runtime}"
WINDOW="${HERMES_YOLO_TMUX_WINDOW:-hermes-yolo}"
REMOTE_REPO="${HERMES_REMOTE_REPO:-/root/.hermes/hermes-agent}"
PROVIDER="${HERMES_YOLO_PROVIDER:-openai-codex}"
MODEL="${HERMES_YOLO_MODEL:-gpt-5.5}"
EXPECTED_TEXT="${HERMES_YOLO_EXPECTED:-WINDBURN_HERMES_YOLO_LOOP_OK}"

ENSURE=0
RESTART=0
SMOKE=0
CONFIRM=0
OUT=""

usage() {
  cat <<'USAGE'
Usage: scripts/hermes-yolo-loop.sh [--out PATH] [--ensure] [--restart] [--smoke] [--confirm-hermes-yolo-loop]

Default mode is read-only inspect. It checks whether the fixed Hermes tmux
session has a live window running `hermes --yolo`.

Mutation/model-call mode requires explicit confirmation:
  scripts/hermes-yolo-loop.sh --ensure --restart --smoke --confirm-hermes-yolo-loop

Environment knobs:
  HERMES_DROPLET_HOST        default 137.184.104.26
  HERMES_TMUX_SESSION        default windburn-hermes-runtime
  HERMES_YOLO_TMUX_WINDOW    default hermes-yolo
  HERMES_YOLO_PROVIDER       default openai-codex
  HERMES_YOLO_MODEL          default gpt-5.5
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      OUT="${2:?missing value for --out}"
      shift 2
      ;;
    --ensure)
      ENSURE=1
      shift
      ;;
    --restart)
      RESTART=1
      ENSURE=1
      shift
      ;;
    --smoke)
      SMOKE=1
      shift
      ;;
    --confirm-hermes-yolo-loop)
      CONFIRM=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if { [ "$ENSURE" -eq 1 ] || [ "$RESTART" -eq 1 ] || [ "$SMOKE" -eq 1 ]; } && [ "$CONFIRM" -ne 1 ]; then
  echo "refusing remote Hermes yolo mutation/model call: pass --confirm-hermes-yolo-loop" >&2
  exit 2
fi

if [ ! -f "$IDENTITY" ]; then
  echo "missing SSH identity: $IDENTITY" >&2
  exit 2
fi

generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
known_hosts="$(mktemp)"
cleanup() {
  rm -f "$known_hosts"
}
trap cleanup EXIT

ssh-keyscan -4 -T "$SSH_TIMEOUT" "$HOST" > "$known_hosts" 2>/dev/null
test -s "$known_hosts"

remote_output="$(
  ssh \
    -i "$IDENTITY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    -o ConnectTimeout="$SSH_TIMEOUT" \
    "$REMOTE_USER@$HOST" \
    'bash -s' -- "$ENSURE" "$RESTART" "$SMOKE" "$SESSION" "$WINDOW" "$REMOTE_REPO" "$PROVIDER" "$MODEL" "$EXPECTED_TEXT" <<'REMOTE'
set -u

ensure="$1"
restart="$2"
smoke="$3"
session="$4"
window="$5"
repo="$6"
provider="$7"
model="$8"
expected="$9"
run_dir=""

echo "host=$(hostname)"
echo "generated_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "ensure=$ensure"
echo "restart=$restart"
echo "smoke=$smoke"
echo "session=$session"
echo "window=$window"
echo "repo=$repo"
echo "provider=$provider"
echo "model=$model"
echo "hermes_bin=$(command -v hermes || true)"
hermes --version 2>&1 | sed 's/^/hermes_version=/'

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux=missing"
  exit 0
fi

echo "tmux=$(tmux -V)"

window_exists() {
  tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null | grep -Fxq "$window"
}

pane_pid() {
  tmux display-message -p -t "$session:$window" '#{pane_pid}' 2>/dev/null || true
}

pane_args() {
  pid="$1"
  if [ -n "$pid" ]; then
    ps -p "$pid" -o args= 2>/dev/null || true
  fi
}

if [ "$ensure" = "1" ]; then
  if ! tmux has-session -t "$session" 2>/dev/null; then
    tmux new-session -d -s "$session" -n shell -c "$repo"
    echo "session_action=created"
  else
    echo "session_action=already_present"
  fi

  cmd="cd $repo && exec hermes --yolo"
  if window_exists; then
    pid="$(pane_pid)"
    args="$(pane_args "$pid")"
    echo "window_action=already_present"
    echo "before_pane_pid=$pid"
    echo "before_pane_args=$args"
    if [ "$restart" = "1" ]; then
      tmux respawn-pane -k -t "$session:$window" "$cmd"
      echo "yolo_action=respawned_restart"
    elif printf '%s\n' "$args" | grep -Eq 'hermes .*--yolo|hermes --yolo'; then
      echo "yolo_action=already_running"
    else
      tmux respawn-pane -k -t "$session:$window" "$cmd"
      echo "yolo_action=respawned"
    fi
  else
    tmux new-window -t "$session" -n "$window" "$cmd"
    echo "window_action=created"
    echo "yolo_action=created"
  fi
  sleep 4
fi

if tmux has-session -t "$session" 2>/dev/null; then
  echo "fixed_tmux_session=present"
else
  echo "fixed_tmux_session=missing"
fi

if window_exists; then
  echo "yolo_window=present"
  pid="$(pane_pid)"
  echo "pane_pid=$pid"
  echo "pane_dead=$(tmux display-message -p -t "$session:$window" '#{pane_dead}' 2>/dev/null || true)"
  echo "pane_current_command=$(tmux display-message -p -t "$session:$window" '#{pane_current_command}' 2>/dev/null || true)"
  echo "pane_args=$(pane_args "$pid")"
  tmux capture-pane -p -t "$session:$window" -S -40 2>/dev/null | tail -40 | sed 's/^/pane=/'
else
  echo "yolo_window=missing"
fi

ps -eo pid,ppid,stat,args | grep -E 'hermes .*--yolo|hermes --yolo|python3 .*hermes .*--yolo|python3 .*hermes --yolo' | grep -v grep | sed 's/^/yolo_process=/'
echo "yolo_process_count=$(ps -eo args | grep -E 'hermes .*--yolo|hermes --yolo|python3 .*hermes .*--yolo|python3 .*hermes --yolo' | grep -v grep | wc -l | tr -d ' ')"

if [ "$smoke" = "1" ]; then
  run_dir="/root/.hermes/runs/windburn-yolo-loop/$(date -u +%Y%m%dT%H%M%SZ)"
  install -d -m 0700 "$run_dir"
  stdout="$run_dir/oneshot.stdout"
  stderr="$run_dir/oneshot.stderr"

  set +e
  timeout 240 hermes --provider "$provider" --model "$model" --yolo --ignore-rules -z "Reply exactly: $expected" >"$stdout" 2>"$stderr"
  code=$?
  set -e

  observed="$(tr -d '\r' < "$stdout" | sed -e 's/[[:space:]]*$//')"
  echo "smoke_artifact_dir=$run_dir"
  echo "oneshot_exit=$code"
  echo "oneshot_stdout_bytes=$(wc -c < "$stdout" | tr -d ' ')"
  echo "oneshot_stderr_bytes=$(wc -c < "$stderr" | tr -d ' ')"
  if [ "$observed" = "$expected" ]; then
    echo "oneshot_output_match=yes"
    echo "oneshot_observed=$observed"
  else
    echo "oneshot_output_match=no"
    sed -n '1,80p' "$stderr" | sed 's/^/oneshot_stderr=/'
    sed -n '1,20p' "$stdout" | sed 's/^/oneshot_stdout=/'
  fi
fi

tmux list-windows -t "$session" -F 'tmux_window=#{window_index}:#{window_name}:#{pane_current_command}:dead=#{pane_dead}' 2>/dev/null | sed 's/^/runtime_window=/'
REMOTE
)"

flags=()
grep -q '^tmux=missing$' <<<"$remote_output" && flags+=("remote tmux missing")
grep -q '^fixed_tmux_session=present$' <<<"$remote_output" || flags+=("fixed tmux session $SESSION missing")
grep -q '^yolo_window=present$' <<<"$remote_output" || flags+=("Hermes yolo tmux window $WINDOW missing")
grep -Eq '^pane_dead=0$' <<<"$remote_output" || flags+=("Hermes yolo pane is dead or unreadable")
grep -Eq '^yolo_process_count=[1-9][0-9]*$' <<<"$remote_output" || flags+=("no live hermes --yolo process found")
if [ "$SMOKE" -eq 1 ]; then
  grep -q '^oneshot_exit=0$' <<<"$remote_output" || flags+=("Hermes yolo one-shot exited non-zero")
  grep -q '^oneshot_output_match=yes$' <<<"$remote_output" || flags+=("Hermes yolo one-shot output mismatch")
fi

overall="PASS"
if [ "${#flags[@]}" -gt 0 ]; then
  overall="FLAG"
fi

emit_flags() {
  if [ "${#flags[@]}" -eq 0 ]; then
    printf -- '- none\n'
    return
  fi
  local item
  for item in "${flags[@]}"; do
    printf -- '- %s\n' "$item"
  done
}

capture() {
  cat <<REPORT
# Hermes Yolo Loop Proof

Generated: \`$generated_utc\`

Target: \`$HOST\`

Fixed tmux session: \`$SESSION\`

Yolo window: \`$WINDOW\`

Mode: ensure=\`$ENSURE\`, restart=\`$RESTART\`, smoke=\`$SMOKE\`

VERDICT: \`$overall\`

## Flags

$(emit_flags)

## Evidence

\`\`\`text
$remote_output
\`\`\`

## Rerun

\`\`\`sh
scripts/hermes-yolo-loop.sh --out docs/remote-workhorse/preflight/HERMES_YOLO_LOOP_PROOF.md
scripts/hermes-yolo-loop.sh --ensure --restart --smoke --confirm-hermes-yolo-loop --out docs/remote-workhorse/preflight/HERMES_YOLO_LOOP_PROOF.md
\`\`\`
REPORT
}

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  capture | tee "$OUT"
else
  capture
fi
