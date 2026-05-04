#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

HOST="${WINDBURN_REMOTE_HOST:-24.144.113.25}"
REMOTE_USER="${WINDBURN_REMOTE_USER:-root}"
IDENTITY="${WINDBURN_SSH_IDENTITY:-$HOME/.ssh/id_ed25519}"
REMOTE_SECRET_PATH="${WINDBURN_REMOTE_PROVIDER_ENV:-/srv/windburn/secrets/provider.env}"

APPLY=0
CONFIRM=0

usage() {
  cat <<'USAGE'
Usage: scripts/remote-provider-smoke.sh [--apply --confirm-provider-smoke]

Default mode is read-only. It checks remote provider secret presence and prints
the repair card if credentials are missing.

Apply mode writes a run artifact under /srv/windburn/runs/provider-smoke and,
when an OpenAI-compatible provider is present, performs a minimal /v1/models
request with curl. Secret values are never printed.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-provider-smoke)
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

if [ ! -f "$IDENTITY" ]; then
  echo "missing SSH identity: $IDENTITY" >&2
  exit 2
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

known_hosts="$tmpdir/known_hosts"
ssh-keyscan -4 -T 10 "$HOST" > "$known_hosts" 2>/dev/null
test -s "$known_hosts"

ssh_base() {
  ssh \
    -i "$IDENTITY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    -o ConnectTimeout=20 \
    "$REMOTE_USER@$HOST" \
    "$@"
}

echo "mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
echo "host=$HOST"
echo "remote_secret_path=$REMOTE_SECRET_PATH"
echo

if [ "$APPLY" -eq 1 ] && [ "$CONFIRM" -ne 1 ]; then
  echo "refusing provider smoke: missing --confirm-provider-smoke" >&2
  exit 2
fi

remote_script='
set -eu

apply="__APPLY__"
secret_path="__SECRET_PATH__"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-provider-smoke"
run_dir="/srv/windburn/runs/provider-smoke/$run_id"

if [ "$apply" = "1" ]; then
  mkdir -p "$run_dir"
fi

present_names=""
if [ -f "$secret_path" ]; then
  # shellcheck disable=SC1090
  . "$secret_path"
  for name in OPENAI_API_KEY OPENAI_BASE_URL HERMES_API_KEY HERMES_PROVIDER_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL XAI_API_KEY XAI_BASE_URL XAI_MODEL; do
    eval "value=\${$name:-}"
    if [ -n "$value" ]; then
      present_names="$present_names$name "
    fi
  done
else
  verdict=FLAG
  reason=REMOTE_PROVIDER_SECRET_MISSING
fi

provider_type=""
provider_base_url=""
provider_api_key=""

if [ -z "${verdict:-}" ]; then
  if [ -n "${OPENAI_API_KEY:-}" ]; then
    provider_type="openai"
    provider_base_url="${OPENAI_BASE_URL:-https://api.openai.com}"
    provider_api_key="$OPENAI_API_KEY"
  elif [ -n "${XAI_API_KEY:-}" ]; then
    provider_type="xai"
    provider_base_url="${XAI_BASE_URL:-https://api.x.ai}"
    provider_api_key="$XAI_API_KEY"
  elif [ -n "${HERMES_API_KEY:-}" ]; then
    if [ -z "${HERMES_PROVIDER_BASE_URL:-}" ]; then
      verdict=FLAG
      reason=HERMES_PROVIDER_BASE_URL_MISSING
    else
      provider_type="hermes"
      provider_base_url="$HERMES_PROVIDER_BASE_URL"
      provider_api_key="$HERMES_API_KEY"
    fi
  fi
fi

if [ -z "${verdict:-}" ]; then
  if [ -n "$provider_api_key" ]; then
    trimmed_base="${provider_base_url%/}"
    case "$trimmed_base" in
      */v1)
        models_url="$trimmed_base/models"
        ;;
      *)
        models_url="$trimmed_base/v1/models"
        ;;
    esac

    if [ "$apply" = "1" ]; then
      http_code="$(curl -sS -o "$run_dir/${provider_type}-models.json" -w "%{http_code}" -H "Authorization: Bearer $provider_api_key" "$models_url" || true)"
      if [ "$http_code" = "200" ]; then
        verdict=PASS
        reason=$(printf "%s_MODELS_OK" "$provider_type" | tr "[:lower:]" "[:upper:]")
      else
        verdict=FLAG
        reason=$(printf "%s_MODELS_HTTP_%s" "$provider_type" "$http_code" | tr "[:lower:]" "[:upper:]")
      fi
    else
      verdict=PASS
      reason=$(printf "%s_SECRET_PRESENT_READ_ONLY" "$provider_type" | tr "[:lower:]" "[:upper:]")
    fi
  else
    verdict=FLAG
    reason=NO_OPENAI_COMPATIBLE_SECRET
  fi
fi

result_json="$(jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg run_id "$run_id" \
  --arg verdict "$verdict" \
  --arg reason "$reason" \
  --arg provider_type "$provider_type" \
  --arg present_names "$present_names" \
  --arg secret_path "$secret_path" \
  --arg hostname "$(hostname)" \
  "{
    schema_version: 1,
    generated_at_utc: \$generated_at,
    run_id: \$run_id,
    hostname: \$hostname,
    verdict: \$verdict,
    reason: \$reason,
    provider_type: (if (\$provider_type | length) == 0 then null else \$provider_type end),
    present_secret_names: (\$present_names | split(\" \") | map(select(length > 0))),
    secret_path: \$secret_path,
    repair_card: (if \$verdict == \"PASS\" then null else {
      id: \"REMOTE_PROVIDER_SECRET_REPAIR\",
      action: \"Run scripts/remote-secret-sync.sh with allowlisted OpenAI or Hermes provider variables, then rerun provider smoke.\"
    } end)
  }")"

if [ "$apply" = "1" ]; then
  printf "%s\n" "$result_json" | tee "$run_dir/result.json"
  echo "artifact=$run_dir/result.json"
else
  printf "%s\n" "$result_json"
  echo "dry-run complete; no artifact written"
fi
'

remote_script="${remote_script/__APPLY__/$APPLY}"
remote_script="${remote_script/__SECRET_PATH__/$REMOTE_SECRET_PATH}"

ssh_base "bash -lc $(printf '%q' "$remote_script")"
