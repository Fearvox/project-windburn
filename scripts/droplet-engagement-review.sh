#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

CCR_HOST="${CCR_DROPLET_HOST:-165.232.146.188}"
CCR_PUBLIC_ENDPOINT="${CCR_PUBLIC_ENDPOINT:-http://165.232.146.188:8888}"
CCR_INTERNAL_ENDPOINT="${CCR_INTERNAL_ENDPOINT:-http://100.65.234.77:8080}"
HERMES_HOST="${HERMES_DROPLET_HOST:-137.184.104.26}"
WINDBURN_HOST="${WINDBURN_REMOTE_HOST:-24.144.113.25}"
REMOTE_USER="${WINDBURN_REMOTE_USER:-root}"
IDENTITY="${WINDBURN_SSH_IDENTITY:-$HOME/.ssh/id_ed25519}"
SSH_TIMEOUT="${WINDBURN_SSH_TIMEOUT:-12}"
CURL_TIMEOUT="${WINDBURN_CURL_TIMEOUT:-8}"
OUT=""
SKIP_SSH=0
SKIP_DOCTL=0

usage() {
  cat <<'USAGE'
Usage: scripts/droplet-engagement-review.sh [--out PATH] [--skip-ssh] [--skip-doctl]

Runs a read-only engagement review across the current Windburn/CCR droplets.
It checks cloud inventory availability, SSH reachability, service/task signals,
CCR embedding smoke, remote health timers, and local code-review-graph freshness.

Environment overrides:
  CCR_DROPLET_HOST          defaults to 165.232.146.188
  CCR_PUBLIC_ENDPOINT       defaults to http://165.232.146.188:8888
  CCR_INTERNAL_ENDPOINT     defaults to http://100.65.234.77:8080
  HERMES_DROPLET_HOST       defaults to 137.184.104.26
  WINDBURN_REMOTE_HOST      defaults to 24.144.113.25
  WINDBURN_REMOTE_USER      defaults to root
  WINDBURN_SSH_IDENTITY     defaults to ~/.ssh/id_ed25519
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      OUT="${2:?missing value for --out}"
      shift 2
      ;;
    --skip-ssh)
      SKIP_SSH=1
      shift
      ;;
    --skip-doctl)
      SKIP_DOCTL=1
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

escape_md() {
  sed 's/|/\\|/g'
}

first_line() {
  awk 'NF { print; exit }'
}

summarize_result() {
  local text="$1"
  local fallback="$2"
  local line
  line="$(printf '%s\n' "$text" | first_line | tr -d '\r' | escape_md)"
  if [ -z "$line" ]; then
    printf '%s' "$fallback"
  else
    printf '%s' "$line"
  fi
}

ssh_script() {
  local host="$1"
  local script="$2"
  local known_hosts

  known_hosts="$(mktemp)"
  if ! ssh-keyscan -4 -T "$SSH_TIMEOUT" "$host" > "$known_hosts" 2>/dev/null; then
    rm -f "$known_hosts"
    return 1
  fi

  ssh \
    -i "$IDENTITY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    -o ConnectTimeout="$SSH_TIMEOUT" \
    "$REMOTE_USER@$host" \
    'bash -s' <<< "$script"
  local status=$?
  rm -f "$known_hosts"
  return "$status"
}

capture_local() {
  "$@" 2>&1
}

generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
current_head="$(git -C "$ROOT" rev-parse --short=12 HEAD 2>/dev/null || true)"
git_dirty="$(git -C "$ROOT" status --short 2>/dev/null | wc -l | tr -d ' ')"

doctl_status="SKIPPED"
doctl_summary="--skip-doctl"
doctl_droplets=""
doctl_uptime=""
doctl_alerts=""
doctl_uptime_status="SKIPPED"
doctl_uptime_summary="--skip-doctl"
doctl_alert_status="SKIPPED"
doctl_alert_summary="--skip-doctl"

if [ "$SKIP_DOCTL" -eq 0 ]; then
  if doctl_account="$(capture_local doctl account get --format Status --no-header)"; then
    doctl_status="PASS"
    doctl_summary="account_status=$(summarize_result "$doctl_account" "ok")"
    doctl_droplets="$(capture_local doctl compute droplet list --format Name,PublicIPv4,Region,Status,Tags --no-header || true)"
    if doctl_uptime_raw="$(capture_local doctl monitoring uptime list --format Name,Type,Target,Enabled --no-header)"; then
      if [ -n "$(printf '%s\n' "$doctl_uptime_raw" | first_line)" ]; then
        doctl_uptime_status="PASS"
        doctl_uptime_summary="$(summarize_result "$doctl_uptime_raw" "uptime checks captured")"
        doctl_uptime="$doctl_uptime_raw"
      else
        doctl_uptime_status="FLAG"
        doctl_uptime_summary="no uptime checks returned"
        doctl_uptime="$doctl_uptime_summary"
      fi
    else
      doctl_uptime_status="FLAG"
      doctl_uptime_summary="$(summarize_result "$doctl_uptime_raw" "uptime checks unavailable")"
      doctl_uptime="$doctl_uptime_raw"
    fi
    if doctl_alert_raw="$(capture_local doctl monitoring alert list --format Type,Description,Enabled --no-header)"; then
      doctl_alert_rows="$(printf '%s\n' "$doctl_alert_raw" | awk 'NF && !($1 == "UUID" && $2 == "Type") && !($1 == "Type" && $2 == "Description")')"
      if [ -n "$(printf '%s\n' "$doctl_alert_rows" | first_line)" ]; then
        doctl_alert_status="PASS"
        doctl_alert_summary="$(summarize_result "$doctl_alert_rows" "monitoring alerts captured")"
      else
        doctl_alert_status="FLAG"
        doctl_alert_summary="no monitoring alerts returned"
      fi
      doctl_alerts="${doctl_alert_raw:-no monitoring alerts returned}"
    else
      doctl_alert_status="FLAG"
      doctl_alert_summary="$(summarize_result "$doctl_alert_raw" "monitoring alerts unavailable")"
      doctl_alerts="$doctl_alert_raw"
    fi
  else
    doctl_status="FLAG"
    doctl_summary="$(summarize_result "$doctl_account" "doctl unavailable")"
    doctl_uptime_status="FLAG"
    doctl_uptime_summary="doctl unavailable"
    doctl_alert_status="FLAG"
    doctl_alert_summary="doctl unavailable"
  fi
fi

public_ccr_status="FLAG"
public_ccr_summary=""
if public_models="$(capture_local curl -fsS --max-time "$CURL_TIMEOUT" "$CCR_PUBLIC_ENDPOINT/v1/models")"; then
  public_ccr_status="PASS"
  public_ccr_summary="public /v1/models reachable"
else
  public_ccr_summary="$(summarize_result "$public_models" "public endpoint unavailable")"
fi

ccr_status="SKIPPED"
ccr_output="--skip-ssh"
hermes_status="SKIPPED"
hermes_output="--skip-ssh"
windburn_status="SKIPPED"
windburn_output="--skip-ssh"

if [ "$SKIP_SSH" -eq 0 ]; then
  if [ ! -f "$IDENTITY" ]; then
    ccr_status="FLAG"
    hermes_status="FLAG"
    windburn_status="FLAG"
    ccr_output="missing SSH identity: $IDENTITY"
    hermes_output="$ccr_output"
    windburn_output="$ccr_output"
  else
    ccr_probe=$(cat <<CCR
set -u
endpoint="$CCR_INTERNAL_ENDPOINT"
echo "host=\$(hostname)"
echo "uptime=\$(uptime -p 2>/dev/null || uptime)"
echo "bge_m3_embed_service=\$(systemctl is-active bge-m3-embed.service 2>/dev/null || true)"
echo "llama_server_service=\$(systemctl is-active llama-server.service 2>/dev/null || true)"
echo "llama_server_process_count=\$(pgrep -fc 'llama-server.*embeddings' 2>/dev/null || true)"
ss -ltnp 2>/dev/null | awk '/:8080|:8888|llama-server/ { sub(/users:.*/, "users:[redacted]"); print "listener=" \$0 }' || true
if models="\$(curl -fsS --max-time $CURL_TIMEOUT "\$endpoint/v1/models" 2>&1)"; then
  echo "models_status=pass"
  printf '%s\n' "\$models" | tr '\n' ' ' | cut -c 1-220 | sed 's/^/models_sample=/'
else
  echo "models_status=fail"
  printf '%s\n' "\$models" | head -1 | sed 's/^/models_error=/'
fi
if emb="\$(curl -fsS --max-time $CURL_TIMEOUT "\$endpoint/v1/embeddings" -H 'Content-Type: application/json' --data '{"model":"bge-m3","input":"windburn droplet engagement smoke"}' 2>&1)"; then
  echo "embeddings_status=pass"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "\$emb" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("embedding_len="+str(len(d["data"][0]["embedding"])))' 2>/dev/null || true
  else
    echo "embedding_response_bytes=\${#emb}"
  fi
else
  echo "embeddings_status=fail"
  printf '%s\n' "\$emb" | head -1 | sed 's/^/embeddings_error=/'
fi
CCR
)
    if ccr_output="$(ssh_script "$CCR_HOST" "$ccr_probe" 2>&1)"; then
      if printf '%s\n' "$ccr_output" | grep -q 'embeddings_status=pass'; then
        ccr_status="PASS_INTERNAL"
      else
        ccr_status="FLAG"
      fi
    else
      ccr_status="FLAG"
    fi

    hermes_probe=$(cat <<'HERMES'
set -u
echo "host=$(hostname)"
echo "uptime=$(uptime -p 2>/dev/null || uptime)"
for unit in hermes-gateway.service multica.service do-agent.service droplet-agent.service tailscaled.service; do
  safe_name="$(printf '%s' "$unit" | tr '.-' '__')"
  echo "${safe_name}=$(systemctl is-active "$unit" 2>/dev/null || true)"
done
echo "hermes_chat_count=$(pgrep -fc 'hermes chat' 2>/dev/null || true)"
echo "research_vault_mcp_count=$(pgrep -fc 'research-vault-mcp' 2>/dev/null || true)"
echo "multica_daemon_count=$(pgrep -fc 'multica daemon' 2>/dev/null || true)"
echo "recent_gateway_warning_count=$(journalctl -u hermes-gateway.service --since '60 min ago' --no-pager 2>/dev/null | grep -Eic 'warn|warning|closed|error' || true)"
ss -ltnp 2>/dev/null | awk '/:8644|:18765|:18766|:18767|:18768|:19514|:3001|:22/ { sub(/users:.*/, "users:[redacted]"); print "listener=" $0 }' || true
HERMES
)
    if hermes_output="$(ssh_script "$HERMES_HOST" "$hermes_probe" 2>&1)"; then
      if printf '%s\n' "$hermes_output" | grep -q 'hermes_gateway_service=active' &&
        printf '%s\n' "$hermes_output" | grep -Eq 'hermes_chat_count=[1-9]|research_vault_mcp_count=[1-9]|multica_daemon_count=[1-9]'; then
        hermes_status="ENGAGED_FLAG_HEALTH_GATE"
      else
        hermes_status="FLAG"
      fi
    else
      hermes_status="FLAG"
    fi

    windburn_probe=$(cat <<'WINDBURN'
set -u
echo "host=$(hostname)"
echo "uptime=$(uptime -p 2>/dev/null || uptime)"
. /etc/os-release 2>/dev/null || true
echo "os=${PRETTY_NAME:-unknown}"
echo "windburn_health_service=$(systemctl is-active windburn-health.service 2>/dev/null || true)"
echo "windburn_health_timer=$(systemctl is-active windburn-health.timer 2>/dev/null || true)"
echo "failed_units=$(systemctl --failed --no-legend 2>/dev/null | wc -l | tr -d ' ')"
if [ -f /srv/windburn/evidence/health/current.json ]; then
  stat -c 'health_file_mtime=%y' /srv/windburn/evidence/health/current.json 2>/dev/null || true
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import json
with open("/srv/windburn/evidence/health/current.json", "r", encoding="utf-8") as fh:
    d = json.load(fh)
print("health_generated_at_utc=" + str(d.get("generated_at_utc")))
print("health_system_state=" + str(d.get("system_state")))
print("health_failed_units=" + str(d.get("failed_units")))
PY
  fi
else
  echo "health_file=missing"
fi
echo "hermes_chat_count=$(pgrep -fc 'hermes chat' 2>/dev/null || true)"
echo "research_vault_mcp_count=$(pgrep -fc 'research-vault-mcp' 2>/dev/null || true)"
ss -ltnp 2>/dev/null | awk '/:22|:19514|:3001|:8644|:1876[5-8]/ { sub(/users:.*/, "users:[redacted]"); print "listener=" $0 }' || true
WINDBURN
)
    if windburn_output="$(ssh_script "$WINDBURN_HOST" "$windburn_probe" 2>&1)"; then
      if printf '%s\n' "$windburn_output" | grep -q 'windburn_health_timer=active' &&
        printf '%s\n' "$windburn_output" | grep -q 'health_system_state=running'; then
        windburn_status="FOUNDATION_ONLY"
      else
        windburn_status="FLAG"
      fi
    else
      windburn_status="FLAG"
    fi
  fi
fi

graph_status="FLAG"
graph_summary=""
graph_proof="$ROOT/docs/remote-workhorse/phase1/CODE_REVIEW_GRAPH_PROOF.json"
if [ -f "$graph_proof" ]; then
  proof_commit="$(grep -m1 '"built_at_commit_prefix"' "$graph_proof" | sed -E 's/.*"built_at_commit_prefix": "([^"]+)".*/\1/' || true)"
  if [ -n "$proof_commit" ] && [ "$proof_commit" = "$current_head" ] && [ "$git_dirty" = "0" ]; then
    graph_status="PASS"
    graph_summary="proof fresh for HEAD $current_head"
  else
    graph_summary="proof_commit=${proof_commit:-unknown}; head=${current_head:-unknown}; dirty_files=$git_dirty"
  fi
else
  graph_summary="missing CODE_REVIEW_GRAPH_PROOF.json"
fi

if command -v uvx >/dev/null 2>&1; then
  graph_cli="$(capture_local timeout 20 uvx code-review-graph status --repo "$ROOT" || true)"
else
  graph_cli="uvx missing"
fi

overall="PASS"
if [ "$doctl_status" != "PASS" ] ||
  [ "$doctl_uptime_status" != "PASS" ] ||
  [ "$doctl_alert_status" != "PASS" ] ||
  [ "$public_ccr_status" != "PASS" ] ||
  [ "$ccr_status" != "PASS_INTERNAL" ] ||
  [ "$hermes_status" != "ENGAGED" ] ||
  [ "$windburn_status" != "ENGAGED" ] ||
  [ "$graph_status" != "PASS" ]; then
  overall="FLAG"
fi

capture() {
  cat <<REPORT
# Droplet Engagement Review

Generated: \`$generated_utc\`

Target repo: \`$ROOT\`

VERDICT: \`$overall\`

## Contract

This is a read-only droplet engagement review. It does not restart services,
change firewall rules, edit cloud resources, sync secrets, or mutate remote
runtime state. It uses temporary SSH host-key files and prints sanitized process
counts/listeners instead of raw task transcripts.

## Summary

| Surface | Status | Evidence |
| --- | --- | --- |
| DigitalOcean control plane | \`$doctl_status\` | $doctl_summary |
| DigitalOcean uptime checks | \`$doctl_uptime_status\` | $doctl_uptime_summary |
| DigitalOcean monitoring alerts | \`$doctl_alert_status\` | $doctl_alert_summary |
| CCR public route | \`$public_ccr_status\` | $public_ccr_summary |
| \`ccr-droplet\` internal embedding route | \`$ccr_status\` | SSH + \`$CCR_INTERNAL_ENDPOINT/v1/models\` + embeddings smoke |
| \`hermes-nyc1\` task/MCP engagement | \`$hermes_status\` | Hermes gateway/process/MCP counts over SSH |
| \`windburn-workhorse-nyc1\` foundation health | \`$windburn_status\` | health timer + current health JSON over SSH |
| code-review-graph freshness | \`$graph_status\` | $graph_summary |

## Droplets

| Name | Host | Expected role | Current review |
| --- | --- | --- | --- |
| \`ccr-droplet\` | \`$CCR_HOST\` | CCR/RV embedding node | Internal embedding API is the trusted route; public \`:8888\` is only a legacy canary unless restored. |
| \`hermes-nyc1\` | \`$HERMES_HOST\` | Hermes/Multica/RV task lane | Engaged when gateway plus Hermes, Multica, or Research Vault MCP process counts are non-zero; still needs a dedicated health gate. |
| \`windburn-workhorse-nyc1\` | \`$WINDBURN_HOST\` | NixOS workhorse foundation | Healthy foundation when timer and health JSON are fresh; not counted as task-engaged until a runner/MCP process appears. |

## DigitalOcean Evidence

\`\`\`text
status=$doctl_status
$doctl_summary
\`\`\`

### Droplet Inventory

\`\`\`text
${doctl_droplets:-not captured}
\`\`\`

### Uptime Checks

\`\`\`text
${doctl_uptime:-not captured}
\`\`\`

### Monitoring Alerts

\`\`\`text
${doctl_alerts:-not captured}
\`\`\`

## CCR Evidence

Public canary:

\`\`\`text
endpoint=$CCR_PUBLIC_ENDPOINT/v1/models
status=$public_ccr_status
$public_ccr_summary
\`\`\`

Internal SSH/Tailscale canary:

\`\`\`text
$ccr_output
\`\`\`

## Hermes Evidence

\`\`\`text
$hermes_output
\`\`\`

## Windburn Workhorse Evidence

\`\`\`text
$windburn_output
\`\`\`

## code-review-graph Evidence

\`\`\`text
$graph_summary

$graph_cli
\`\`\`

## Closeout Rule

- \`PASS\`: cloud control plane works, CCR smoke passes, Hermes has a health
  gate plus task/MCP engagement, Windburn has task-level engagement, uptime
  checks cover the active route, and code-review-graph proof is fresh for the
  current clean HEAD.
- \`FLAG\`: one or more probes are usable but incomplete, stale, or on a
  fallback route. \`FOUNDATION_ONLY\` is a FLAG for "every droplet engaged"
  unless the task explicitly accepts foundation-only evidence.
- \`BLOCK\`: SSH/API access is unavailable for the target lane or a required
  service smoke fails on the only trusted route.

## Rerun

\`\`\`sh
scripts/droplet-engagement-review.sh --out docs/remote-workhorse/preflight/DROPLET_ENGAGEMENT_REVIEW.md
\`\`\`
REPORT
}

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  capture | tee "$OUT"
else
  capture
fi
