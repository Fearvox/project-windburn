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

ALLOWLIST=(
  OPENAI_API_KEY
  OPENAI_BASE_URL
  OPENAI_ORG_ID
  OPENAI_PROJECT_ID
  HERMES_API_KEY
  HERMES_PROVIDER_BASE_URL
  HERMES_PROVIDER_MODEL
  ANTHROPIC_AUTH_TOKEN
  ANTHROPIC_BASE_URL
  ANTHROPIC_MODEL
  ANTHROPIC_DEFAULT_HAIKU_MODEL
  ANTHROPIC_DEFAULT_SONNET_MODEL
  ANTHROPIC_DEFAULT_OPUS_MODEL
)

usage() {
  cat <<'USAGE'
Usage: scripts/remote-secret-sync.sh [--apply --confirm-remote-secret-sync]

Default mode is dry-run. It reports which allowlisted provider variables are
present locally without printing values.

Apply mode writes only allowlisted non-empty variables to the remote root-only
provider env file. It never writes secrets to the repository.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-remote-secret-sync)
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
provider_env="$tmpdir/provider.env"
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

scp_base() {
  scp \
    -i "$IDENTITY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    -o ConnectTimeout=20 \
    "$@"
}

present=()
quote_env_value() {
  local value="$1"
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
    echo "refusing multiline provider secret value" >&2
    exit 1
  fi
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  value="${value//\`/\\\`}"
  printf '"%s"' "$value"
}

for name in "${ALLOWLIST[@]}"; do
  if [ -n "${!name:-}" ]; then
    present+=("$name")
    printf '%s=' "$name" >> "$provider_env"
    quote_env_value "${!name}" >> "$provider_env"
    printf '\n' >> "$provider_env"
  fi
done

echo "mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
echo "host=$HOST"
echo "remote_secret_path=$REMOTE_SECRET_PATH"
echo "allowlisted_present_count=${#present[@]}"
if [ "${#present[@]}" -gt 0 ]; then
  printf 'allowlisted_present_names='
  printf '%s ' "${present[@]}"
  echo
else
  echo "allowlisted_present_names="
fi

echo
echo "remote_secret_probe:"
ssh_base "set -e; test -d /srv/windburn/secrets; ls -ld /srv/windburn/secrets; test -f '$REMOTE_SECRET_PATH' && echo provider_env=present || echo provider_env=absent"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "dry-run complete; no secrets were copied"
  exit 0
fi

if [ "$CONFIRM" -ne 1 ]; then
  echo "refusing secret sync: missing --confirm-remote-secret-sync" >&2
  exit 2
fi

if [ "${#present[@]}" -eq 0 ]; then
  echo "refusing secret sync: no allowlisted provider variables are present" >&2
  exit 1
fi

remote_tmp="/tmp/windburn-provider-env-$$"
scp_base "$provider_env" "$REMOTE_USER@$HOST:$remote_tmp"
ssh_base "set -e; install -o root -g root -m 0600 '$remote_tmp' '$REMOTE_SECRET_PATH'; rm -f '$remote_tmp'; ls -l '$REMOTE_SECRET_PATH'"

echo
echo "secret_sync_complete=1"
