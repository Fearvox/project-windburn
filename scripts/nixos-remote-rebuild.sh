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
HOST_DIR="$ROOT/nixos/hosts/windburn-workhorse-nyc1"

APPLY=0
MODE="test"
CONFIRM=0

usage() {
  cat <<'USAGE'
Usage: scripts/nixos-remote-rebuild.sh [--apply --confirm-remote-nixos-rebuild] [--mode test|switch]

Default mode is read-only. It proves SSH and the current NixOS state without
copying files or rebuilding.

Apply mode backs up /etc/nixos, syncs the Windburn host module and modules/,
then runs nixos-rebuild test or switch. Use test first for new modules.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-remote-nixos-rebuild)
      CONFIRM=1
      shift
      ;;
    --mode)
      MODE="${2:?missing value for --mode}"
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

case "$MODE" in
  test|switch) ;;
  *)
    echo "unsupported mode: $MODE" >&2
    exit 2
    ;;
esac

if [ ! -f "$IDENTITY" ]; then
  echo "missing SSH identity: $IDENTITY" >&2
  exit 2
fi

if [ ! -f "$HOST_DIR/windburn-workhorse.nix" ]; then
  echo "missing host module: $HOST_DIR/windburn-workhorse.nix" >&2
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
    -e "ssh -i $IDENTITY -o BatchMode=yes -o IdentitiesOnly=yes -o UserKnownHostsFile=$known_hosts -o StrictHostKeyChecking=yes -o ConnectTimeout=20" \
    "$@"
}

echo "mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
echo "rebuild_mode=$MODE"
echo "host=$HOST"
echo

echo "remote_nixos_probe:"
ssh_base \
  'set -e
   . /etc/os-release
   echo "id=$ID"
   echo "os=$PRETTY_NAME"
   echo "hostname=$(hostname)"
   echo "kernel=$(uname -srmo)"
   echo "nixos_version=$(nixos-version)"
   echo "system_state=$(systemctl is-system-running || true)"
   echo "failed_units=$(systemctl --failed --no-legend --plain | sed "/^$/d" | wc -l | tr -d " ")"
   echo "current_system=$(readlink -f /run/current-system)"
   test "${ID:-}" = nixos'

echo
echo "local_payload:"
find "$HOST_DIR" -maxdepth 3 -type f | sort | sed "s#^$ROOT/##"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "dry-run complete; remote host was not modified"
  exit 0
fi

if [ "$CONFIRM" -ne 1 ]; then
  echo "refusing rebuild: missing --confirm-remote-nixos-rebuild" >&2
  exit 2
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

echo
echo "backup_remote_etc_nixos:"
ssh_base "set -e; mkdir -p /root/windburn-nixos/backups; tar -C /etc -czf /root/windburn-nixos/backups/etc-nixos-$timestamp.tar.gz nixos; echo backup=/root/windburn-nixos/backups/etc-nixos-$timestamp.tar.gz"

echo
echo "sync_remote_nixos_payload:"
rsync_base "$HOST_DIR/windburn-workhorse.nix" "$REMOTE_USER@$HOST:/etc/nixos/windburn-workhorse.nix"
if [ -d "$HOST_DIR/modules" ]; then
  rsync_base "$HOST_DIR/modules/" "$REMOTE_USER@$HOST:/etc/nixos/modules/"
fi

echo
echo "remote_nixos_rebuild_$MODE:"
ssh_base "set -e; nixos-rebuild $MODE --show-trace"

echo
echo "post_rebuild_probe:"
ssh_base \
  'set -e
   . /etc/os-release
   echo "id=$ID"
   echo "os=$PRETTY_NAME"
   echo "hostname=$(hostname)"
   echo "kernel=$(uname -srmo)"
   echo "nixos_version=$(nixos-version)"
   echo "system_state=$(systemctl is-system-running || true)"
   echo "failed_units=$(systemctl --failed --no-legend --plain | sed "/^$/d" | wc -l | tr -d " ")"
   echo "current_system=$(readlink -f /run/current-system)"
   systemctl status windburn-health.service --no-pager || true
   systemctl status windburn-runner-status.service --no-pager || true
   systemctl status windburn-runner-status.timer --no-pager || true
   test -x /run/current-system/sw/bin/windburn-health
   /run/current-system/sw/bin/windburn-health >/tmp/windburn-health-smoke.json
   cat /tmp/windburn-health-smoke.json
   test -f /srv/windburn/evidence/health/current.json
   test -x /run/current-system/sw/bin/codex
   timeout 90 /run/current-system/sw/bin/codex --version | sed -n "1,8p"
   test -x /run/current-system/sw/bin/windburn-codex-yolo-ensure
   test -x /run/current-system/sw/bin/windburn-codex-runtime-status
   systemctl start windburn-codex-yolo-ensure.service
   /run/current-system/sw/bin/windburn-codex-runtime-status >/tmp/windburn-codex-runtime-status-smoke.json
   cat /tmp/windburn-codex-runtime-status-smoke.json
   jq -e ".schema_version == 1 and .status == \"PASS\" and .secret_values_recorded == false and .redacted_public_safe == true and .codex.command_present == true and .lane.codex_window_present == true and .lane.pane_alive == true and .lane.process_count >= 1" /tmp/windburn-codex-runtime-status-smoke.json >/dev/null
   test -x /run/current-system/sw/bin/hermes
   timeout 180 /run/current-system/sw/bin/hermes --version | sed -n "1,8p"
   test -x /run/current-system/sw/bin/uv
	   test -x /run/current-system/sw/bin/windburn-hermes-runtime-status
	   /run/current-system/sw/bin/windburn-hermes-runtime-status >/tmp/windburn-hermes-runtime-status-smoke.json
	   cat /tmp/windburn-hermes-runtime-status-smoke.json
	   jq -e ".schema_version == 1 and .secret_values_recorded == false and .redacted_public_safe == true and .hermes.command_present == true and .uv.command_present == true" /tmp/windburn-hermes-runtime-status-smoke.json >/dev/null
	   test -x /run/current-system/sw/bin/windburn-hermes-yolo-ensure
	   test -x /run/current-system/sw/bin/windburn-hermes-yolo-status
	   systemctl start windburn-hermes-yolo-ensure.service
	   /run/current-system/sw/bin/windburn-hermes-yolo-status >/tmp/windburn-hermes-yolo-status-smoke.json
	   cat /tmp/windburn-hermes-yolo-status-smoke.json
	   jq -e ".schema_version == 1 and .status == \"PASS\" and .secret_values_recorded == false and .redacted_public_safe == true and .lane.fixed_session_present == true and .lane.yolo_window_present == true and .lane.pane_alive == true and .lane.yolo_process_count >= 1" /tmp/windburn-hermes-yolo-status-smoke.json >/dev/null
	   test -x /run/current-system/sw/bin/herdr
	   timeout 30 /run/current-system/sw/bin/herdr --version | sed -n "1,4p"
	   test -x /run/current-system/sw/bin/windburn-herdr-status
	   systemctl restart windburn-herdr-server.service
	   sleep 2
	   systemctl is-active --quiet windburn-herdr-server.service
	   /run/current-system/sw/bin/windburn-herdr-status >/tmp/windburn-herdr-status-smoke.json
	   cat /tmp/windburn-herdr-status-smoke.json
	   jq -e ".schema_version == 1 and .status == \"PASS\" and .secret_values_recorded == false and .redacted_public_safe == true and .herdr.command_present == true and .server.service_active == true and .server.socket_present == true and .server.socket_api_status == \"PASS\" and .operator_surface.attach_target_redacted == true" /tmp/windburn-herdr-status-smoke.json >/dev/null
	   test -x /run/current-system/sw/bin/windburn-research-appliance-status
	   test -x /run/current-system/sw/bin/windburn-research-runner
	   /run/current-system/sw/bin/windburn-research-appliance-status >/tmp/windburn-research-appliance-status-smoke.json
	   cat /tmp/windburn-research-appliance-status-smoke.json
	   jq -e ".schema_version == 1 and .status == \"PASS\" and .secret_values_recorded == false and .redacted_public_safe == true and (.capabilities | index(\"research-run-card-validation\") != null) and (.capabilities | index(\"dry-run-decision-impact-traces\") != null) and (.capabilities | index(\"agent-memory-causality\") != null) and (.capabilities | index(\"huggingface-export-gated\") != null)" /tmp/windburn-research-appliance-status-smoke.json >/dev/null
	   test -x /run/current-system/sw/bin/windburn-runner-status
	   /run/current-system/sw/bin/windburn-runner-status >/tmp/windburn-runner-status-smoke.json
	   cat /tmp/windburn-runner-status-smoke.json
	   jq -e ".schema_version == 1 and .secret_values_recorded == false and .redacted_public_safe == true and .codex_tui.status == \"PASS\" and .hermes_yolo.status == \"PASS\" and .herdr_cockpit.status == \"PASS\" and .research_appliance.status == \"PASS\"" /tmp/windburn-runner-status-smoke.json >/dev/null
   test -f /srv/windburn/evidence/runner/current.json'

echo
echo "rebuild_complete=1"
