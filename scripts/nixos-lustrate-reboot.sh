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
DROPLET_ID="${WINDBURN_DROPLET_ID:-568689911}"
SNAPSHOT_ID="${WINDBURN_BASE_SNAPSHOT_ID:-227115138}"
REMOTE_USER="${WINDBURN_REMOTE_USER:-root}"
IDENTITY="${WINDBURN_SSH_IDENTITY:-$HOME/.ssh/id_ed25519}"
WAIT_SECONDS="${WINDBURN_LUSTRATE_WAIT_SECONDS:-600}"

APPLY=0
CONFIRM_REBOOT=0
CONFIRM_SNAPSHOT_ID=""

usage() {
  cat <<'USAGE'
Usage: scripts/nixos-lustrate-reboot.sh [--apply --confirm-lustrate-reboot --confirm-snapshot-id ID]

Default mode is dry-run. It proves that the remote host has a staged
NIXOS_LUSTRATE conversion and prints the guarded reboot command.

Apply mode reboots the selected DigitalOcean Droplet, then waits for SSH to
return as NixOS. It never reruns nixos-infect.

Environment:
  WINDBURN_REMOTE_HOST             default 24.144.113.25
  WINDBURN_DROPLET_ID              default 568689911
  WINDBURN_BASE_SNAPSHOT_ID        default 227115138
  WINDBURN_REMOTE_USER             default root
  WINDBURN_SSH_IDENTITY            default ~/.ssh/id_ed25519
  WINDBURN_LUSTRATE_WAIT_SECONDS   default 600
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-lustrate-reboot)
      CONFIRM_REBOOT=1
      shift
      ;;
    --confirm-snapshot-id)
      CONFIRM_SNAPSHOT_ID="${2:?missing value for --confirm-snapshot-id}"
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

if ! command -v doctl >/dev/null 2>&1; then
  echo "missing doctl" >&2
  exit 2
fi

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
pre_fingerprints="$tmpdir/pre-fingerprints"
post_fingerprints="$tmpdir/post-fingerprints"
post_probe="$tmpdir/post-probe"
post_error="$tmpdir/post-error"

make_known_hosts() {
  local out="$1"
  : > "$out"
  ssh-keyscan -4 -T 10 "$HOST" > "$out" 2>/dev/null
  test -s "$out"
}

ssh_base() {
  local kh="$1"
  shift
  ssh \
    -i "$IDENTITY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$kh" \
    -o StrictHostKeyChecking=yes \
    -o ConnectTimeout=20 \
    "$REMOTE_USER@$HOST" \
    "$@"
}

make_known_hosts "$known_hosts"
ssh-keygen -lf "$known_hosts" > "$pre_fingerprints"

echo "mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
echo "host=$HOST"
echo "droplet_id=$DROPLET_ID"
echo "snapshot_id=$SNAPSHOT_ID"
echo

echo "droplet_proof:"
doctl compute droplet get "$DROPLET_ID" \
  --format ID,Name,PublicIPv4,PrivateIPv4,Region,Image,Status,Tags,Features \
  --no-header

echo
echo "snapshot_proof:"
doctl compute snapshot get "$SNAPSHOT_ID" \
  --format ID,Name,ResourceId,ResourceType,Regions,MinDiskSize,Size \
  --no-header

echo
echo "pre_reboot_ssh_host_fingerprints:"
cat "$pre_fingerprints"

echo
echo "staged_remote_probe:"
ssh_base "$known_hosts" \
  'set -e
   echo "whoami=$(whoami)"
   echo "hostname=$(hostname)"
   . /etc/os-release
   echo "os=$PRETTY_NAME"
   echo "kernel=$(uname -srmo)"
   echo "boot_id=$(cat /proc/sys/kernel/random/boot_id)"
   test -e /etc/NIXOS && echo "etc_NIXOS=present" || { echo "etc_NIXOS=absent"; exit 1; }
   test -e /etc/NIXOS_LUSTRATE && echo "lustrate=present" || { echo "lustrate=absent"; exit 1; }
   test -e /nix/var/nix/profiles/system && echo "system_profile=present" || { echo "system_profile=absent"; exit 1; }
   echo "system_profile_target=$(readlink -f /nix/var/nix/profiles/system)"
   test -x /nix/var/nix/profiles/system/sw/bin/nixos-rebuild && echo "system_nixos_rebuild=present" || { echo "system_nixos_rebuild=absent"; exit 1; }
   grep -R "windburn-workhorse.nix" -n /etc/nixos/configuration.nix'

echo
printf 'apply_command=scripts/nixos-lustrate-reboot.sh --apply --confirm-lustrate-reboot --confirm-snapshot-id %s\n' "$SNAPSHOT_ID"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "dry-run complete; droplet was not rebooted"
  exit 0
fi

if [ "$CONFIRM_REBOOT" -ne 1 ]; then
  echo "refusing reboot: missing --confirm-lustrate-reboot" >&2
  exit 2
fi

if [ "$CONFIRM_SNAPSHOT_ID" != "$SNAPSHOT_ID" ]; then
  echo "refusing reboot: --confirm-snapshot-id must equal $SNAPSHOT_ID" >&2
  exit 2
fi

echo
echo "reboot_action:"
doctl compute droplet-action reboot "$DROPLET_ID" --wait \
  --format ID,Status,Type,StartedAt,CompletedAt,ResourceID,Region \
  --no-header

echo
echo "waiting_for_nixos_ssh:"
deadline=$((SECONDS + WAIT_SECONDS))
while [ "$SECONDS" -lt "$deadline" ]; do
  if make_known_hosts "$known_hosts"; then
    if ssh_base "$known_hosts" \
      'set -e
       echo "whoami=$(whoami)"
       echo "hostname=$(hostname)"
       . /etc/os-release
       echo "os=$PRETTY_NAME"
       echo "kernel=$(uname -srmo)"
       echo "boot_id=$(cat /proc/sys/kernel/random/boot_id)"
       test "${ID:-}" = nixos
       echo "nixos_version=$(nixos-version)"
       echo "system_state=$(systemctl is-system-running || true)"
       echo "sshd_state=$(systemctl is-active sshd || true)"
       echo "root_fs=$(df -h / | tail -1)"
       echo "memory=$(free -h | awk '\''/^Mem:/ {print $0}'\'')" ' \
      > "$post_probe" 2> "$post_error"; then
      break
    fi
  fi
  sleep 10
done

if [ ! -s "$post_probe" ]; then
  echo "NixOS SSH proof did not pass within ${WAIT_SECONDS}s" >&2
  cat "$post_error" >&2 || true
  exit 1
fi

ssh-keygen -lf "$known_hosts" > "$post_fingerprints"
if cmp -s "$pre_fingerprints" "$post_fingerprints"; then
  echo "ssh_host_key_changed=0"
else
  echo "ssh_host_key_changed=1"
  echo "post_reboot_ssh_host_fingerprints:"
  cat "$post_fingerprints"
fi

cat "$post_probe"
echo
echo "nixos_reboot_complete=1"
