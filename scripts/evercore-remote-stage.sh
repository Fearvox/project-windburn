#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

EVEROS_REPO_ROOT="${EVEROS_REPO_ROOT:-$ROOT/../EverOS}"
REMOTE_BASE="${EVERCORE_REMOTE_BASE:-/srv/evercore}"
HOST="${WINDBURN_REMOTE_HOST:-}"
REMOTE_USER="${WINDBURN_REMOTE_USER:-root}"
IDENTITY="${WINDBURN_SSH_IDENTITY:-$HOME/.ssh/id_ed25519}"

APPLY=0
CONFIRM=0

usage() {
  cat <<'USAGE'
Usage: scripts/evercore-remote-stage.sh [--apply --confirm-evercore-stage]

Default mode is local dry-run. It validates the EverOS deploy payload without
copying files to the remote host.

Apply mode requires WINDBURN_REMOTE_HOST and an existing remote secret env file.
It stages the compose file and EverOS checkout used by the EverCore NixOS
service. It does not run nixos-rebuild.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-evercore-stage)
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

compose_source="$EVEROS_REPO_ROOT/use-cases/hermes-everos-memory/deploy/nixos/docker-compose.remote.yaml"
evercore_source="$EVEROS_REPO_ROOT/methods/EverCore"

if [ ! -f "$compose_source" ]; then
  echo "missing compose source: use-cases/hermes-everos-memory/deploy/nixos/docker-compose.remote.yaml" >&2
  exit 2
fi

if [ ! -d "$evercore_source" ]; then
  echo "missing EverCore source: methods/EverCore" >&2
  exit 2
fi

echo "mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
echo "remote_base=$REMOTE_BASE"
echo
echo "local_payload:"
echo "everos_repo_root=configured"
echo "compose_source=use-cases/hermes-everos-memory/deploy/nixos/docker-compose.remote.yaml"
echo "evercore_source=methods/EverCore"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "dry-run complete; remote host was not modified"
  exit 0
fi

if [ "$CONFIRM" -ne 1 ]; then
  echo "refusing stage: missing --confirm-evercore-stage" >&2
  exit 2
fi

if [ -z "$HOST" ]; then
  echo "refusing stage: WINDBURN_REMOTE_HOST is not set" >&2
  exit 2
fi

if [ ! -f "$IDENTITY" ]; then
  echo "missing SSH identity" >&2
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

rsync_base() {
  rsync -az --delete \
    --exclude ".git/" \
    --exclude ".planning/" \
    --exclude ".playwright-mcp/" \
    --exclude ".env" \
    --exclude ".env.*" \
    --exclude ".venv/" \
    --exclude "__pycache__/" \
    --exclude "*.pyc" \
    --exclude "node_modules/" \
    --exclude "tmp/" \
    --exclude "var/" \
    -e "ssh -i $IDENTITY -o BatchMode=yes -o IdentitiesOnly=yes -o UserKnownHostsFile=$known_hosts -o StrictHostKeyChecking=yes -o ConnectTimeout=20" \
    "$@"
}

echo
echo "remote_preflight:"
ssh_base "set -e; test -f '$REMOTE_BASE/evercore.env'; echo secret_env=present"

echo
echo "stage_remote_dirs:"
ssh_base "set -e; install -d -m 0750 '$REMOTE_BASE' '$REMOTE_BASE/repo' '$REMOTE_BASE/backups' '$REMOTE_BASE/evidence'"

echo
echo "stage_compose:"
rsync_base "$compose_source" "$REMOTE_USER@$HOST:$REMOTE_BASE/docker-compose.remote.yaml"
echo "compose=staged"

echo
echo "stage_repo:"
rsync_base "$EVEROS_REPO_ROOT/" "$REMOTE_USER@$HOST:$REMOTE_BASE/repo/"
echo "repo=staged"

echo
echo "remote_payload_probe:"
ssh_base "set -e; test -f '$REMOTE_BASE/docker-compose.remote.yaml'; test -d '$REMOTE_BASE/repo/methods/EverCore'; echo evercore_payload=present"

echo
echo "stage_complete=1"
