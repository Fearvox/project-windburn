#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

HOST="${HERMES_DROPLET_HOST:-}"
REMOTE_USER="${WINDBURN_REMOTE_USER:-root}"
IDENTITY="${WINDBURN_SSH_IDENTITY:-$HOME/.ssh/id_ed25519}"
SSH_TIMEOUT="${WINDBURN_SSH_TIMEOUT:-12}"
FIXED_SESSION="${HERMES_TMUX_SESSION:-windburn-hermes-runtime}"
REMOTE_REPO="${HERMES_REMOTE_REPO:-/root/.hermes/hermes-agent}"
ROUTE_LABEL="${HERMES_ROUTE_LABEL:-remote-workhorse}"
INSTANCE_LABEL="${HERMES_INSTANCE_LABEL:-windburn-workhorse-nyc1}"
HERMES_PROVIDER_VALUE="${HERMES_PROVIDER:-openai-codex}"
HERMES_MODEL_VALUE="${HERMES_MODEL:-gpt-5.5}"
HERMES_AGENT_REPO_URL_VALUE="${HERMES_AGENT_REPO_URL:-}"
HERMES_INSTALL_COMMAND_VALUE="${HERMES_INSTALL_COMMAND:-}"

BOOTSTRAP=0
CONFIRM=0
OUT=""
generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
overall="PASS"
exit_code=0
block_reason=""
flags=()
evidence=()
health_gate_verdict="SKIP"

usage() {
  cat <<'USAGE'
Usage: scripts/hermes-bootstrap.sh [--out PATH] [--bootstrap --confirm-hermes-bootstrap]

Default mode is read-only inspect for the redacted remote-workhorse Hermes route.

Mutation requires both:
  --bootstrap
  --confirm-hermes-bootstrap

Environment overrides:
  HERMES_DROPLET_HOST
  WINDBURN_REMOTE_USER
  WINDBURN_SSH_IDENTITY
  WINDBURN_SSH_TIMEOUT
  HERMES_REMOTE_REPO
  HERMES_TMUX_SESSION
  HERMES_ROUTE_LABEL
  HERMES_INSTANCE_LABEL
  HERMES_AGENT_REPO_URL
  HERMES_INSTALL_COMMAND
  HERMES_PROVIDER
  HERMES_MODEL
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      OUT="${2:?missing value for --out}"
      shift 2
      ;;
    --bootstrap)
      BOOTSTRAP=1
      shift
      ;;
    --confirm-hermes-bootstrap)
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

if [ "$BOOTSTRAP" -eq 1 ] && [ "$CONFIRM" -ne 1 ]; then
  echo "refusing remote mutation: pass --confirm-hermes-bootstrap" >&2
  exit 2
fi

add_flag() {
  flags+=("$1")
}

add_evidence() {
  evidence+=("$1=$2")
}

escape_block() {
  printf '%s\n' "$1"
}

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

emit_evidence() {
  if [ "${#evidence[@]}" -eq 0 ]; then
    printf 'none\n'
    return
  fi

  local item
  for item in "${evidence[@]}"; do
    printf '%s\n' "$item"
  done
}

capture() {
  local mode
  mode="inspect"
  if [ "$BOOTSTRAP" -eq 1 ]; then
    mode="bootstrap"
  fi

  cat <<REPORT
# Hermes Bootstrap

Generated: \`$generated_utc\`

Route label: \`$ROUTE_LABEL\`

Instance label: \`$INSTANCE_LABEL\`

Mode: \`$mode\`

VERDICT: \`$overall\`

## Flags

$(emit_flags)

## Evidence

\`\`\`text
$(emit_evidence)
\`\`\`

## Rerun

\`\`\`sh
scripts/hermes-bootstrap.sh --out docs/remote-workhorse/preflight/HERMES_BOOTSTRAP.md
scripts/hermes-bootstrap.sh --bootstrap --confirm-hermes-bootstrap --out docs/remote-workhorse/preflight/HERMES_BOOTSTRAP.md
\`\`\`
REPORT
}

finish() {
  if [ -n "$OUT" ]; then
    mkdir -p "$(dirname "$OUT")"
    capture | tee "$OUT"
  else
    capture
  fi
  exit "$exit_code"
}

set_block() {
  overall="BLOCK"
  exit_code=1
  block_reason="$1"
}

if [ -z "$HOST" ]; then
  echo "BLOCK hermes_bootstrap: missing HERMES_DROPLET_HOST" >&2
  echo "hint: set HERMES_DROPLET_HOST in .env.local" >&2
  set_block "missing HERMES_DROPLET_HOST"
  add_flag "hermes_bootstrap: missing HERMES_DROPLET_HOST"
  add_evidence "route_label" "$ROUTE_LABEL"
  add_evidence "instance_label" "$INSTANCE_LABEL"
  add_evidence "mode" "$([ "$BOOTSTRAP" -eq 1 ] && printf 'bootstrap' || printf 'inspect')"
  add_evidence "host_env" "missing"
  finish
fi

if [ ! -f "$IDENTITY" ]; then
  echo "BLOCK hermes_bootstrap: missing SSH identity env WINDBURN_SSH_IDENTITY" >&2
  set_block "missing SSH identity env WINDBURN_SSH_IDENTITY"
  add_flag "hermes_bootstrap: missing SSH identity env WINDBURN_SSH_IDENTITY"
  add_evidence "route_label" "$ROUTE_LABEL"
  add_evidence "instance_label" "$INSTANCE_LABEL"
  add_evidence "mode" "$([ "$BOOTSTRAP" -eq 1 ] && printf 'bootstrap' || printf 'inspect')"
  add_evidence "ssh_identity" "missing"
  finish
fi

known_hosts="$(mktemp)"
cleanup() {
  rm -f "$known_hosts"
}
trap cleanup EXIT

if ! ssh-keyscan -4 -T "$SSH_TIMEOUT" "$HOST" > "$known_hosts" 2>/dev/null || [ ! -s "$known_hosts" ]; then
  echo "BLOCK hermes_bootstrap: ssh keyscan failed for $ROUTE_LABEL" >&2
  set_block "ssh keyscan failed"
  add_flag "hermes_bootstrap: ssh keyscan failed"
  add_evidence "route_label" "$ROUTE_LABEL"
  add_evidence "instance_label" "$INSTANCE_LABEL"
  add_evidence "ssh_keyscan" "failed"
  finish
fi

remote_output="$(
  ssh \
    -i "$IDENTITY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    -o ConnectTimeout="$SSH_TIMEOUT" \
    "$REMOTE_USER@$HOST" \
    'bash -s' -- \
    "$BOOTSTRAP" \
    "$FIXED_SESSION" \
    "$REMOTE_REPO" \
    "$ROUTE_LABEL" \
    "$INSTANCE_LABEL" \
    "$HERMES_PROVIDER_VALUE" \
    "$HERMES_MODEL_VALUE" \
    "$HERMES_AGENT_REPO_URL_VALUE" \
    "$HERMES_INSTALL_COMMAND_VALUE" <<'REMOTE'
set -u

bootstrap="$1"
session="$2"
repo="$3"
route_label="$4"
instance_label="$5"
provider="$6"
model="$7"
repo_url="$8"
install_command="$9"

repo_state="missing"
hermes_bin="missing"
hermes_version="missing"
tmux_state="missing"
fixed_tmux_session="missing"
env_local_state="missing"
install_status="not_needed"
gateway_state="unknown"
hermes_chat_count="unknown"
yolo_process_count="unknown"
verdict="PASS"
reason="inspect_ok"

line() {
  printf '%s=%s\n' "$1" "$2"
}

if [ -d "$repo/.git" ]; then
  repo_state="present"
elif [ -e "$repo" ]; then
  repo_state="invalid"
fi

if [ "$bootstrap" = "1" ] && [ "$repo_state" = "missing" ]; then
  if [ -z "$repo_url" ]; then
    verdict="BLOCK"
    reason="missing HERMES_AGENT_REPO_URL"
  else
    mkdir -p "$(dirname "$repo")"
    if git clone "$repo_url" "$repo" >/dev/null 2>&1; then
      repo_state="cloned"
    else
      repo_state="clone_failed"
      verdict="BLOCK"
      reason="repo clone failed"
    fi
  fi
fi

if [ "$repo_state" = "invalid" ]; then
  verdict="BLOCK"
  reason="remote repo path exists but is not a git repo"
fi

if [ "$repo_state" = "present" ] || [ "$repo_state" = "cloned" ]; then
  env_local_path="$repo/.env.local"

  if [ -f "$env_local_path" ]; then
    env_local_state="present"
  fi

  if [ "$bootstrap" = "1" ] && [ "$verdict" != "BLOCK" ]; then
    tmp_env="$(mktemp)"
    if [ -f "$env_local_path" ]; then
      grep -Ev '^(HERMES_PROVIDER|HERMES_MODEL|HERMES_TMUX_SESSION|HERMES_ROUTE_LABEL|HERMES_INSTANCE_LABEL)=' "$env_local_path" > "$tmp_env" || true
    fi
    {
      cat "$tmp_env"
      printf 'HERMES_PROVIDER=%s\n' "$provider"
      printf 'HERMES_MODEL=%s\n' "$model"
      printf 'HERMES_TMUX_SESSION=%s\n' "$session"
      printf 'HERMES_ROUTE_LABEL=%s\n' "$route_label"
      printf 'HERMES_INSTANCE_LABEL=%s\n' "$instance_label"
    } > "$env_local_path"
    rm -f "$tmp_env"
    env_local_state="written"
  fi
fi

if command -v hermes >/dev/null 2>&1; then
  hermes_bin="present"
  if hermes --version >/dev/null 2>&1; then
    hermes_version="present"
  fi
fi

if [ "$bootstrap" = "1" ] && [ "$hermes_bin" = "missing" ] && [ "$verdict" != "BLOCK" ]; then
  if [ -n "$install_command" ] && { [ "$repo_state" = "present" ] || [ "$repo_state" = "cloned" ]; }; then
    install_status="attempted"
    if bash -lc "cd $(printf '%q' "$repo") && $install_command" >/dev/null 2>&1; then
      if command -v hermes >/dev/null 2>&1; then
        hermes_bin="present"
        if hermes --version >/dev/null 2>&1; then
          hermes_version="present"
        fi
      else
        install_status="failed"
      fi
    else
      install_status="failed"
    fi
  else
    install_status="flagged"
  fi
fi

if command -v tmux >/dev/null 2>&1; then
  tmux_state="present"
  if tmux has-session -t "$session" 2>/dev/null; then
    fixed_tmux_session="present"
  fi

  if [ "$bootstrap" = "1" ] && [ "$fixed_tmux_session" = "missing" ] && { [ "$repo_state" = "present" ] || [ "$repo_state" = "cloned" ]; }; then
    if tmux new-session -d -s "$session" -n shell -c "$repo" >/dev/null 2>&1; then
      fixed_tmux_session="created"
    else
      fixed_tmux_session="missing"
      if [ "$verdict" != "BLOCK" ]; then
        verdict="FLAG"
        reason="tmux session creation failed"
      fi
    fi
  fi
else
  tmux_state="missing"
fi

if command -v systemctl >/dev/null 2>&1; then
  gateway_state="$(systemctl is-active hermes-gateway.service 2>/dev/null || true)"
  if [ -z "$gateway_state" ]; then
    gateway_state="unknown"
  fi
fi

if command -v pgrep >/dev/null 2>&1; then
  hermes_chat_count="$(pgrep -fc 'hermes chat' 2>/dev/null || true)"
  yolo_process_count="$(pgrep -fc 'hermes .*--yolo|hermes --yolo' 2>/dev/null || true)"
fi

if [ "$verdict" != "BLOCK" ]; then
  if [ "$repo_state" != "present" ] && [ "$repo_state" != "cloned" ]; then
    verdict="FLAG"
    reason="repo missing"
  elif [ "$hermes_bin" != "present" ]; then
    verdict="FLAG"
    reason="hermes binary missing"
  elif [ "$tmux_state" != "present" ]; then
    verdict="FLAG"
    reason="tmux missing"
  elif [ "$fixed_tmux_session" != "present" ] && [ "$fixed_tmux_session" != "created" ]; then
    verdict="FLAG"
    reason="fixed tmux session missing"
  elif [ "$gateway_state" = "inactive" ] || [ "$gateway_state" = "failed" ] || [ "$gateway_state" = "activating" ] || [ "$gateway_state" = "deactivating" ]; then
    verdict="FLAG"
    reason="gateway service not healthy"
  elif [ "$install_status" = "flagged" ]; then
    verdict="FLAG"
    reason="hermes_install_command_unknown"
  elif [ "$install_status" = "failed" ]; then
    verdict="FLAG"
    reason="hermes install failed"
  else
    verdict="PASS"
    reason="hermes bootstrap ready"
  fi
fi

line "route_label" "$route_label"
line "instance_label" "$instance_label"
line "mode" "$([ "$bootstrap" = "1" ] && printf 'bootstrap' || printf 'inspect')"
line "repo_state" "$repo_state"
line "hermes_bin" "$hermes_bin"
line "hermes_version" "$hermes_version"
line "tmux" "$tmux_state"
line "fixed_tmux_session" "$fixed_tmux_session"
line "env_local" "$env_local_state"
line "install_status" "$install_status"
line "hermes_gateway_service" "$gateway_state"
line "hermes_chat_count" "$hermes_chat_count"
line "yolo_process_count" "$yolo_process_count"
line "verdict" "$verdict"
line "reason" "$reason"
REMOTE
)" || ssh_status=$?

ssh_status="${ssh_status:-0}"
if [ "$ssh_status" -ne 0 ]; then
  echo "BLOCK hermes_bootstrap: ssh failed for $ROUTE_LABEL" >&2
  set_block "ssh failed"
  add_flag "hermes_bootstrap: ssh failed"
  add_evidence "route_label" "$ROUTE_LABEL"
  add_evidence "instance_label" "$INSTANCE_LABEL"
  add_evidence "ssh" "failed"
  finish
fi

line_value() {
  local key="$1"
  awk -F= -v target="$key" '$1 == target { sub(/^[^=]*=/, "", $0); print $0; exit }' <<<"$remote_output"
}

remote_verdict="$(line_value verdict)"
remote_reason="$(line_value reason)"
repo_state="$(line_value repo_state)"
hermes_bin_state="$(line_value hermes_bin)"
hermes_version_state="$(line_value hermes_version)"
tmux_state="$(line_value tmux)"
fixed_tmux_session_state="$(line_value fixed_tmux_session)"
env_local_state="$(line_value env_local)"
install_status_state="$(line_value install_status)"
gateway_state="$(line_value hermes_gateway_service)"
hermes_chat_count_state="$(line_value hermes_chat_count)"
yolo_process_count_state="$(line_value yolo_process_count)"

add_evidence "route_label" "$ROUTE_LABEL"
add_evidence "instance_label" "$INSTANCE_LABEL"
add_evidence "mode" "$([ "$BOOTSTRAP" -eq 1 ] && printf 'bootstrap' || printf 'inspect')"
add_evidence "repo_state" "${repo_state:-unknown}"
add_evidence "hermes_bin" "${hermes_bin_state:-unknown}"
add_evidence "hermes_version" "${hermes_version_state:-unknown}"
add_evidence "tmux" "${tmux_state:-unknown}"
add_evidence "fixed_tmux_session" "${fixed_tmux_session_state:-unknown}"
add_evidence "env_local" "${env_local_state:-unknown}"
add_evidence "install_status" "${install_status_state:-unknown}"
add_evidence "hermes_gateway_service" "${gateway_state:-unknown}"
add_evidence "hermes_chat_count" "${hermes_chat_count_state:-unknown}"
add_evidence "yolo_process_count" "${yolo_process_count_state:-unknown}"

if [ "$BOOTSTRAP" -eq 1 ] && [ "${remote_verdict:-}" != "BLOCK" ]; then
  health_gate_output="$(
    HERMES_DROPLET_HOST="$HOST" \
    HERMES_TMUX_SESSION="$FIXED_SESSION" \
    HERMES_ROUTE_LABEL="$ROUTE_LABEL" \
    HERMES_INSTANCE_LABEL="$INSTANCE_LABEL" \
    WINDBURN_REMOTE_USER="$REMOTE_USER" \
    WINDBURN_SSH_IDENTITY="$IDENTITY" \
    WINDBURN_SSH_TIMEOUT="$SSH_TIMEOUT" \
    "$ROOT/scripts/hermes-health-gate.sh" 2>&1
  )" || health_gate_status=$?
  health_gate_status="${health_gate_status:-0}"
  health_gate_verdict="$(printf '%s\n' "$health_gate_output" | awk -F'`' '/^VERDICT: `/ { print $2; exit }')"
  if [ -z "$health_gate_verdict" ]; then
    if [ "$health_gate_status" -ne 0 ]; then
      health_gate_verdict="BLOCK"
    else
      health_gate_verdict="SKIP"
    fi
  fi
else
  health_gate_verdict="SKIP"
fi

add_evidence "health_gate_verdict" "$health_gate_verdict"

case "${remote_verdict:-BLOCK}" in
  PASS)
    overall="PASS"
    ;;
  FLAG)
    overall="FLAG"
    ;;
  BLOCK)
    overall="BLOCK"
    exit_code=1
    ;;
  *)
    overall="BLOCK"
    exit_code=1
    remote_reason="unknown remote verdict"
    ;;
esac

if [ "$health_gate_verdict" = "FLAG" ] && [ "$overall" = "PASS" ]; then
  overall="FLAG"
fi
if [ "$health_gate_verdict" = "BLOCK" ]; then
  overall="BLOCK"
  exit_code=1
fi

if [ "${repo_state:-}" = "missing" ]; then
  add_flag "Hermes repo missing on $ROUTE_LABEL"
fi
if [ "${repo_state:-}" = "invalid" ]; then
  add_flag "Hermes repo path is not a git repo"
fi
if [ "${repo_state:-}" = "clone_failed" ]; then
  add_flag "Hermes repo clone failed"
fi
if [ "${hermes_bin_state:-}" != "present" ]; then
  add_flag "Hermes binary missing"
fi
if [ "${tmux_state:-}" != "present" ]; then
  add_flag "tmux missing"
fi
if [ "${fixed_tmux_session_state:-}" != "present" ] && [ "${fixed_tmux_session_state:-}" != "created" ]; then
  add_flag "fixed Hermes tmux session missing"
fi
if [ "${install_status_state:-}" = "flagged" ]; then
  add_flag "FLAG hermes_install_command_unknown"
fi
if [ "${install_status_state:-}" = "failed" ]; then
  add_flag "Hermes install command failed"
fi
if [ "${gateway_state:-}" = "inactive" ] || [ "${gateway_state:-}" = "failed" ] || [ "${gateway_state:-}" = "activating" ] || [ "${gateway_state:-}" = "deactivating" ]; then
  add_flag "hermes-gateway.service not healthy"
fi
if [ -n "${remote_reason:-}" ] && [ "$overall" != "PASS" ]; then
  add_flag "$remote_reason"
fi
if [ "$health_gate_verdict" = "FLAG" ]; then
  add_flag "Hermes health gate returned FLAG after bootstrap"
fi
if [ "$health_gate_verdict" = "BLOCK" ]; then
  add_flag "Hermes health gate returned BLOCK after bootstrap"
fi

if [ "$overall" = "BLOCK" ] && [ -n "${remote_reason:-}" ]; then
  echo "BLOCK hermes_bootstrap: $remote_reason" >&2
fi

finish
