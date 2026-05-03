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
FIXED_SESSION="${HERMES_TMUX_SESSION:-windburn-hermes-runtime}"
OUT=""

usage() {
  cat <<'USAGE'
Usage: scripts/hermes-health-gate.sh [--out PATH]

Read-only Hermes health gate for hermes-nyc1. It checks systemd services,
Hermes version/update state, task/MCP process counts, recent gateway warnings,
listeners, and the fixed tmux runtime entry.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      OUT="${2:?missing value for --out}"
      shift 2
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
    'bash -s' -- "$FIXED_SESSION" <<'REMOTE'
set -u
fixed_session="$1"
repo="/root/.hermes/hermes-agent"
echo "host=$(hostname)"
echo "uptime=$(uptime -p 2>/dev/null || uptime)"
echo "hermes_bin=$(command -v hermes || true)"
hermes --version 2>&1 | sed 's/^/hermes_version=/'
hermes update --check 2>&1 | sed 's/^/hermes_update_check=/'
if [ -d "$repo/.git" ]; then
  git -C "$repo" status --short --branch 2>&1 | sed 's/^/hermes_git_status=/'
  git -C "$repo" rev-parse --short=12 HEAD 2>&1 | sed 's/^/hermes_git_head=/'
  git -C "$repo" rev-parse --short=12 origin/main 2>&1 | sed 's/^/hermes_origin_main=/'
fi
for unit in hermes-gateway.service do-agent.service droplet-agent.service tailscaled.service; do
  safe_name="$(printf '%s' "$unit" | tr '.-' '__')"
  echo "${safe_name}=$(systemctl is-active "$unit" 2>/dev/null || true)"
done
echo "hermes_chat_count=$(pgrep -fc 'hermes chat' 2>/dev/null || true)"
echo "research_vault_mcp_count=$(pgrep -fc 'research-vault-mcp' 2>/dev/null || true)"
echo "multica_daemon_count=$(pgrep -fc 'multica daemon' 2>/dev/null || true)"
echo "recent_gateway_warning_count=$(journalctl -u hermes-gateway.service --since '60 min ago' --no-pager 2>/dev/null | grep -Eic 'warn|warning' || true)"
echo "recent_gateway_error_count=$(journalctl -u hermes-gateway.service --since '60 min ago' --no-pager 2>/dev/null | grep -Eic 'error|critical|traceback|exception' || true)"
if command -v tmux >/dev/null 2>&1; then
  echo "tmux_version=$(tmux -V)"
  if tmux has-session -t "$fixed_session" 2>/dev/null; then
    echo "fixed_tmux_session=present"
  else
    echo "fixed_tmux_session=missing"
  fi
  tmux ls 2>&1 | sed 's/^/tmux_session=/'
else
  echo "tmux_version=missing"
  echo "fixed_tmux_session=missing"
fi
ss -ltnp 2>/dev/null | awk '/:8644|:18765|:18766|:18767|:18768|:19514|:3001|:22/ { sub(/users:.*/, "users:[redacted]"); print "listener=" $0 }' || true
REMOTE
)"

flags=()
grep -q '^hermes_gateway_service=active$' <<<"$remote_output" || flags+=("hermes-gateway.service not active")
grep -q '^do_agent_service=active$' <<<"$remote_output" || flags+=("do-agent.service not active")
grep -q '^droplet_agent_service=active$' <<<"$remote_output" || flags+=("droplet-agent.service not active")
grep -q '^tailscaled_service=active$' <<<"$remote_output" || flags+=("tailscaled.service not active")
grep -Eq '^hermes_chat_count=[1-9]|^research_vault_mcp_count=[1-9]|^multica_daemon_count=[1-9]' <<<"$remote_output" || flags+=("no Hermes/RV/Multica task engagement process count")
grep -q '^fixed_tmux_session=present$' <<<"$remote_output" || flags+=("fixed tmux session $FIXED_SESSION missing")
if grep -q 'Update available' <<<"$remote_output"; then
  flags+=("Hermes update available")
fi
warning_count="$(awk -F= '$1 == "recent_gateway_warning_count" { print $2; exit }' <<<"$remote_output")"
error_count="$(awk -F= '$1 == "recent_gateway_error_count" { print $2; exit }' <<<"$remote_output")"
if [ -n "$error_count" ] && [ "$error_count" != "0" ]; then
  flags+=("recent gateway error count is $error_count")
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
# Hermes Health Gate

Generated: \`$generated_utc\`

Target: \`$HOST\`

Fixed tmux session: \`$FIXED_SESSION\`

VERDICT: \`$overall\`

## Flags

$(emit_flags)

## Evidence

\`\`\`text
$remote_output
\`\`\`

## Rerun

\`\`\`sh
scripts/hermes-health-gate.sh --out docs/remote-workhorse/preflight/HERMES_HEALTH_GATE.md
\`\`\`
REPORT
}

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  capture | tee "$OUT"
else
  capture
fi
