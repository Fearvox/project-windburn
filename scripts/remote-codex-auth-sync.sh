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
LOCAL_AUTH_PATH="${WINDBURN_LOCAL_CODEX_AUTH:-$HOME/.codex/auth.json}"
LOCAL_HERMES_AUTH_PATH="${WINDBURN_LOCAL_HERMES_AUTH:-$HOME/.hermes/auth.json}"
REMOTE_SECRET_PATH="${WINDBURN_REMOTE_CODEX_AUTH:-/srv/windburn/secrets/codex-auth.json}"
REMOTE_ROOT_AUTH_PATH="${WINDBURN_REMOTE_ROOT_CODEX_AUTH:-/root/.codex/auth.json}"
REMOTE_HERMES_AUTH_PATH="${WINDBURN_REMOTE_HERMES_AUTH:-/root/.hermes/auth.json}"

APPLY=0
CONFIRM=0

usage() {
  cat <<'USAGE'
Usage: scripts/remote-codex-auth-sync.sh [--apply --confirm-remote-codex-auth-sync]

Default mode is dry-run. It validates local Codex CLI and Hermes auth JSON and
reports only safe metadata: key names, token presence, token lengths, and remote
file status.

Apply mode copies the local Codex CLI auth JSON to root-only remote paths:
  /srv/windburn/secrets/codex-auth.json
  /root/.codex/auth.json

It also writes a minimal Hermes auth store at /root/.hermes/auth.json containing
only providers.openai-codex, sourced from local ~/.hermes/auth.json when present
and falling back to local ~/.codex/auth.json tokens.

Secret values are never printed and are never written to the repository.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-remote-codex-auth-sync)
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

if [ ! -f "$LOCAL_AUTH_PATH" ]; then
  echo "missing local Codex auth JSON: $LOCAL_AUTH_PATH" >&2
  exit 1
fi

jq empty "$LOCAL_AUTH_PATH" >/dev/null
if [ -f "$LOCAL_HERMES_AUTH_PATH" ]; then
  jq empty "$LOCAL_HERMES_AUTH_PATH" >/dev/null
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

known_hosts="$tmpdir/known_hosts"
hermes_auth="$tmpdir/hermes-auth.json"
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

print_local_summary() {
  echo "codex_cli:"
  jq -r '
    [
      "auth_mode=" + ((.auth_mode // "null") | tostring),
      "top_level_keys=" + (keys_unsorted | join(",")),
      "openai_api_key_length=" + (((.OPENAI_API_KEY? // "") | tostring | length) | tostring),
      "has_tokens_access_token=" + ((((.tokens.access_token? // "") | tostring | length) > 0) | tostring),
      "tokens_access_token_length=" + (((.tokens.access_token? // "") | tostring | length) | tostring),
      "has_tokens_refresh_token=" + ((((.tokens.refresh_token? // "") | tostring | length) > 0) | tostring),
      "last_refresh=" + ((.last_refresh // "null") | tostring)
    ][]
  ' "$LOCAL_AUTH_PATH"

  echo "hermes:"
  if [ -f "$LOCAL_HERMES_AUTH_PATH" ]; then
    jq -r '
      [
        "top_level_keys=" + (keys_unsorted | join(",")),
        "active_provider=" + ((.active_provider // "null") | tostring),
        "has_openai_codex_provider=" + ((.providers["openai-codex"]? != null) | tostring),
        "openai_codex_keys=" + ((.providers["openai-codex"]? // {} | keys_unsorted) | join(",")),
        "openai_codex_has_access_token=" + ((((.providers["openai-codex"].tokens.access_token? // "") | tostring | length) > 0) | tostring),
        "openai_codex_access_token_length=" + (((.providers["openai-codex"].tokens.access_token? // "") | tostring | length) | tostring),
        "openai_codex_has_refresh_token=" + ((((.providers["openai-codex"].tokens.refresh_token? // "") | tostring | length) > 0) | tostring),
        "openai_codex_last_refresh=" + ((.providers["openai-codex"].last_refresh // "null") | tostring)
      ][]
    ' "$LOCAL_HERMES_AUTH_PATH"
  else
    echo "local_hermes_auth=absent"
  fi
}

build_hermes_auth_payload() {
  local source
  if [ -f "$LOCAL_HERMES_AUTH_PATH" ] && jq -e '
      (.providers["openai-codex"].tokens.access_token? // "" | tostring | length) > 0
      and
      (.providers["openai-codex"].tokens.refresh_token? // "" | tostring | length) > 0
    ' "$LOCAL_HERMES_AUTH_PATH" >/dev/null; then
    source="local_hermes_auth"
    jq '
      {
        version: (.version // 1),
        providers: {"openai-codex": .providers["openai-codex"]},
        active_provider: "openai-codex",
        updated_at: (now | todateiso8601)
      }
    ' "$LOCAL_HERMES_AUTH_PATH" > "$hermes_auth"
  else
    source="local_codex_cli_auth"
    jq '
      {
        version: 1,
        providers: {
          "openai-codex": {
            tokens: .tokens,
            last_refresh: (.last_refresh // null),
            auth_mode: (.auth_mode // "chatgpt")
          }
        },
        active_provider: "openai-codex",
        updated_at: (now | todateiso8601)
      }
    ' "$LOCAL_AUTH_PATH" > "$hermes_auth"
  fi

  jq -e '
    (.providers["openai-codex"].tokens.access_token? // "" | tostring | length) > 0
    and
    (.providers["openai-codex"].tokens.refresh_token? // "" | tostring | length) > 0
  ' "$hermes_auth" >/dev/null
  echo "$source"
}

remote_probe_script='
set -eu

secret_path="__REMOTE_SECRET_PATH__"
root_auth_path="__REMOTE_ROOT_AUTH_PATH__"
hermes_auth_path="__REMOTE_HERMES_AUTH_PATH__"

probe_path() {
  path="$1"
  label="$2"
  if [ -f "$path" ]; then
    mode="$(stat -c %a "$path")"
    owner="$(stat -c %U "$path")"
    group="$(stat -c %G "$path")"
    bytes="$(stat -c %s "$path")"
    echo "$label=present mode=$mode owner=$owner group=$group bytes=$bytes"
  else
    echo "$label=absent"
  fi
}

test -d /srv/windburn/secrets && ls -ld /srv/windburn/secrets || echo "secrets_dir=absent"
probe_path "$secret_path" "windburn_codex_auth"
probe_path "$root_auth_path" "root_codex_auth"
probe_path "$hermes_auth_path" "root_hermes_auth"
'

remote_probe_script="${remote_probe_script/__REMOTE_SECRET_PATH__/$REMOTE_SECRET_PATH}"
remote_probe_script="${remote_probe_script/__REMOTE_ROOT_AUTH_PATH__/$REMOTE_ROOT_AUTH_PATH}"
remote_probe_script="${remote_probe_script/__REMOTE_HERMES_AUTH_PATH__/$REMOTE_HERMES_AUTH_PATH}"

hermes_auth_source="$(build_hermes_auth_payload)"

echo "mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
echo "host=$HOST"
echo "local_auth_path=$LOCAL_AUTH_PATH"
echo "remote_secret_path=$REMOTE_SECRET_PATH"
echo "remote_root_auth_path=$REMOTE_ROOT_AUTH_PATH"
echo "remote_hermes_auth_path=$REMOTE_HERMES_AUTH_PATH"
echo "hermes_auth_payload_source=$hermes_auth_source"
echo
echo "local_codex_auth_summary:"
print_local_summary
echo
echo "remote_codex_auth_probe:"
ssh_base "bash -lc $(printf '%q' "$remote_probe_script")"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "dry-run complete; no Codex or Hermes auth was copied"
  exit 0
fi

if [ "$CONFIRM" -ne 1 ]; then
  echo "refusing Codex auth sync: missing --confirm-remote-codex-auth-sync" >&2
  exit 2
fi

remote_tmp="/root/.windburn-codex-auth-sync-$$.json"
remote_hermes_tmp="/root/.windburn-hermes-auth-sync-$$.json"

echo
echo "copy_codex_auth:"
scp_base "$LOCAL_AUTH_PATH" "$REMOTE_USER@$HOST:$remote_tmp"
scp_base "$hermes_auth" "$REMOTE_USER@$HOST:$remote_hermes_tmp"
ssh_base "set -e; install -d -o root -g root -m 0700 /srv/windburn/secrets /root/.codex /root/.hermes; install -o root -g root -m 0600 '$remote_tmp' '$REMOTE_SECRET_PATH'; install -o root -g root -m 0600 '$remote_tmp' '$REMOTE_ROOT_AUTH_PATH'; install -o root -g root -m 0600 '$remote_hermes_tmp' '$REMOTE_HERMES_AUTH_PATH'; rm -f '$remote_tmp' '$remote_hermes_tmp'"

echo
echo "post_sync_remote_codex_auth_probe:"
ssh_base "bash -lc $(printf '%q' "$remote_probe_script")"

echo
echo "codex_auth_sync_complete=1"
