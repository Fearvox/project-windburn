#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

APPLY=0
CONFIRM=0
OUT=""
REGIONS="${WINDBURN_DO_UPTIME_REGIONS:-us_east,us_west,eu_west}"
PERIOD="${WINDBURN_DO_UPTIME_ALERT_PERIOD:-2m}"
ALERT_EMAILS="${WINDBURN_DO_ALERT_EMAILS:-}"
SLACK_CHANNELS="${WINDBURN_DO_ALERT_SLACK_CHANNELS:-}"
SLACK_URLS="${WINDBURN_DO_ALERT_SLACK_URLS:-}"

usage() {
  cat <<'USAGE'
Usage: scripts/digitalocean-observability.sh [--out PATH] [--apply --confirm-do-observability]

Default mode is dry-run. It proves the DigitalOcean monitoring surface, compares
the desired uptime checks/alerts with current account state, and prints the
exact create commands without mutating cloud resources.

Apply mode can create missing ping uptime checks and down_global uptime alerts.
It requires both:
  --apply
  --confirm-do-observability

Alert creation also requires at least one recipient:
  WINDBURN_DO_ALERT_EMAILS
  or WINDBURN_DO_ALERT_SLACK_CHANNELS plus WINDBURN_DO_ALERT_SLACK_URLS
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      OUT="${2:?missing value for --out}"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-do-observability)
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

if [ "$APPLY" -eq 1 ] && [ "$CONFIRM" -ne 1 ]; then
  echo "refusing cloud mutation: pass --confirm-do-observability with --apply" >&2
  exit 2
fi

capture_local() {
  "$@" 2>&1
}

first_line() {
  awk 'NF { print; exit }'
}

has_recipients() {
  if [ -n "$ALERT_EMAILS" ]; then
    return 0
  fi
  if [ -n "$SLACK_CHANNELS" ] && [ -n "$SLACK_URLS" ]; then
    return 0
  fi
  return 1
}

desired_checks=(
  "windburn-workhorse-nyc1-ping|568689911|24.144.113.25|remote-workhorse,windburn"
  "hermes-nyc1-ping|566402244|137.184.104.26|hermes"
  "ccr-droplet-ping|565803713|165.232.146.188|CCR,DS,Evensong,Research-Vault-MCP"
)

generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mode="dry-run"
if [ "$APPLY" -eq 1 ]; then
  mode="apply"
fi

doctl_status="PASS"
account_status=""
droplet_inventory=""
uptime_list=""
metric_alert_list=""
actions=()
flags=()

if ! account_status="$(capture_local doctl account get --format Status --no-header)"; then
  doctl_status="BLOCK"
  flags+=("DigitalOcean account probe failed: $(printf '%s\n' "$account_status" | first_line)")
fi

if [ "$doctl_status" = "PASS" ]; then
  droplet_inventory="$(capture_local doctl compute droplet list --format ID,Name,PublicIPv4,Status,Tags --no-header || true)"
  uptime_list="$(capture_local doctl monitoring uptime list --format ID,Name,Type,Target,Regions,Enabled --no-header || true)"
  metric_alert_list="$(capture_local doctl monitoring alert list --format UUID,Type,Description,Compare,Value,Window,Entities,Tags,Enabled --no-header || true)"
fi

lookup_uptime_line() {
  local name="$1"
  printf '%s\n' "$uptime_list" | awk -v wanted="$name" '$2 == wanted { print; exit }'
}

lookup_uptime_id() {
  local name="$1"
  lookup_uptime_line "$name" | awk '{ print $1 }'
}

create_check() {
  local name="$1"
  local target="$2"
  doctl monitoring uptime create "$name" \
    --target "$target" \
    --type ping \
    --regions "$REGIONS" \
    --enabled true \
    --format ID,Name,Type,Target,Regions,Enabled \
    --no-header
}

create_alert() {
  local check_id="$1"
  local alert_name="$2"
  local cmd=(doctl monitoring uptime alert create "$check_id" --name "$alert_name" --type down_global --period "$PERIOD" --format ID,Name,Type,Period --no-header)
  if [ -n "$ALERT_EMAILS" ]; then
    cmd+=(--emails "$ALERT_EMAILS")
  fi
  if [ -n "$SLACK_CHANNELS" ] && [ -n "$SLACK_URLS" ]; then
    cmd+=(--slack-channels "$SLACK_CHANNELS" --slack-urls "$SLACK_URLS")
  fi
  "${cmd[@]}"
}

for entry in "${desired_checks[@]}"; do
  IFS='|' read -r check_name droplet_id target tags <<<"$entry"
  droplet_line="$(printf '%s\n' "$droplet_inventory" | awk -v id="$droplet_id" '$1 == id { print; exit }')"
  if [ -z "$droplet_line" ]; then
    flags+=("missing droplet inventory for $check_name droplet_id=$droplet_id")
    continue
  fi

  check_line="$(lookup_uptime_line "$check_name")"
  check_id="$(printf '%s\n' "$check_line" | awk '{ print $1 }')"
  if [ -z "$check_line" ]; then
    flags+=("missing uptime check $check_name")
    actions+=("doctl monitoring uptime create $check_name --target $target --type ping --regions $REGIONS --enabled true")
    if [ "$APPLY" -eq 1 ]; then
      created="$(create_check "$check_name" "$target")"
      check_id="$(printf '%s\n' "$created" | awk 'NF { print $1; exit }')"
      uptime_list="${uptime_list}"$'\n'"$created"
    fi
  fi

  alert_name="$check_name-down-global"
  if ! has_recipients; then
    flags+=("missing alert recipient env for $alert_name")
    actions+=("set WINDBURN_DO_ALERT_EMAILS or WINDBURN_DO_ALERT_SLACK_CHANNELS + WINDBURN_DO_ALERT_SLACK_URLS")
    continue
  fi

  if [ -z "$check_id" ]; then
    flags+=("cannot inspect uptime alert before check exists for $check_name")
    continue
  fi

  alert_list="$(capture_local doctl monitoring uptime alert list "$check_id" --format ID,Name,Type,Period --no-header || true)"
  if ! printf '%s\n' "$alert_list" | awk -v wanted="$alert_name" '$2 == wanted { found=1 } END { exit found ? 0 : 1 }'; then
    flags+=("missing uptime alert $alert_name")
    actions+=("doctl monitoring uptime alert create <${check_name}-id> --name $alert_name --type down_global --period $PERIOD --emails \"\$WINDBURN_DO_ALERT_EMAILS\"")
    if [ "$APPLY" -eq 1 ]; then
      create_alert "$check_id" "$alert_name" >/dev/null
    fi
  fi
done

overall="PASS"
if [ "$doctl_status" = "BLOCK" ]; then
  overall="BLOCK"
elif [ "${#flags[@]}" -gt 0 ]; then
  overall="FLAG"
fi

emit_list() {
  local fallback="$1"
  shift
  if [ "$#" -eq 0 ]; then
    printf -- '- %s\n' "$fallback"
    return
  fi
  local item
  for item in "$@"; do
    printf -- '- %s\n' "$item"
  done
}

capture() {
  cat <<REPORT
# DigitalOcean Observability Gate

Generated: \`$generated_utc\`

Mode: \`$mode\`

VERDICT: \`$overall\`

## Contract

This gate is dry-run by default. Apply mode requires \`--apply\` plus
\`--confirm-do-observability\`. It never prints token values or Slack webhook
URLs.

## Desired Uptime Checks

| Name | Droplet ID | Target | Regions |
| --- | --- | --- | --- |
| \`windburn-workhorse-nyc1-ping\` | \`568689911\` | \`24.144.113.25\` | \`$REGIONS\` |
| \`hermes-nyc1-ping\` | \`566402244\` | \`137.184.104.26\` | \`$REGIONS\` |
| \`ccr-droplet-ping\` | \`565803713\` | \`165.232.146.188\` | \`$REGIONS\` |

## Recipient Gate

- email recipients: \`$([ -n "$ALERT_EMAILS" ] && echo present || echo absent)\`
- slack recipients: \`$([ -n "$SLACK_CHANNELS" ] && [ -n "$SLACK_URLS" ] && echo present || echo absent)\`

## Current DigitalOcean State

\`\`\`text
account_status=${account_status:-not captured}

droplets:
${droplet_inventory:-not captured}

uptime_checks:
${uptime_list:-none}

metric_alerts:
${metric_alert_list:-not captured}
\`\`\`

## Flags

$(emit_list "none" "${flags[@]}")

## Planned Actions

$(emit_list "none" "${actions[@]}")

## Rerun

\`\`\`sh
scripts/digitalocean-observability.sh --out docs/remote-workhorse/preflight/DIGITALOCEAN_OBSERVABILITY_GATE.md
\`\`\`
REPORT
}

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  capture | tee "$OUT"
else
  capture
fi
