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
NIX_CHANNEL="${WINDBURN_NIX_CHANNEL:-nixos-25.11}"
HOST_NIX="$ROOT/nixos/hosts/windburn-workhorse-nyc1/windburn-workhorse.nix"

INFECT_COMMIT="40f62a680bb0e8f2f607d79abfaaecd99d59401c"
INFECT_SHA256="4354bd68773b41da65c0e815202c43c8549713b3ed3ff6381c71fbc0b0a840ab"
INFECT_URL="https://raw.githubusercontent.com/elitak/nixos-infect/$INFECT_COMMIT/nixos-infect"

APPLY=0
CONFIRM_CONVERSION=0
CONFIRM_SNAPSHOT_ID=""
REBOOT_AFTER_STAGE=0
CONFIRM_REBOOT=0

usage() {
  cat <<'USAGE'
Usage: scripts/nixos-conversion.sh [--apply --confirm-destructive-nixos-conversion --confirm-snapshot-id ID] [--reboot-after-stage --confirm-lustrate-reboot]

Default mode is dry-run. It proves the selected Droplet, snapshot, SSH path,
and pinned nixos-infect script without modifying the remote host.

Apply mode stages and runs nixos-infect with NO_REBOOT=1. Reboot is optional
and requires --reboot-after-stage plus --confirm-lustrate-reboot.

Environment:
  WINDBURN_REMOTE_HOST        default 24.144.113.25
  WINDBURN_DROPLET_ID         default 568689911
  WINDBURN_BASE_SNAPSHOT_ID   default 227115138
  WINDBURN_REMOTE_USER        default root
  WINDBURN_SSH_IDENTITY       default ~/.ssh/id_ed25519
  WINDBURN_NIX_CHANNEL        default nixos-25.11
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-destructive-nixos-conversion)
      CONFIRM_CONVERSION=1
      shift
      ;;
    --confirm-snapshot-id)
      CONFIRM_SNAPSHOT_ID="${2:?missing value for --confirm-snapshot-id}"
      shift 2
      ;;
    --reboot-after-stage)
      REBOOT_AFTER_STAGE=1
      shift
      ;;
    --confirm-lustrate-reboot)
      CONFIRM_REBOOT=1
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

if [ ! -f "$HOST_NIX" ]; then
  echo "missing host import: $HOST_NIX" >&2
  exit 2
fi

download_infect() {
  local out="$1"
  curl -fsSL "$INFECT_URL" -o "$out"
  local actual
  actual="$(shasum -a 256 "$out" | awk '{print $1}')"
  if [ "$actual" != "$INFECT_SHA256" ]; then
    echo "nixos-infect sha256 mismatch: expected $INFECT_SHA256 got $actual" >&2
    exit 1
  fi
}

make_known_hosts() {
  local known_hosts="$1"
  ssh-keyscan -4 -T 10 "$HOST" > "$known_hosts" 2>/dev/null
}

ssh_base() {
  local known_hosts="$1"
  shift
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
  local known_hosts="$1"
  local source="$2"
  local dest="$3"
  scp \
    -i "$IDENTITY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    -o ConnectTimeout=20 \
    "$source" "$REMOTE_USER@$HOST:$dest"
}

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

infect_script="$tmpdir/nixos-infect"
known_hosts="$tmpdir/known_hosts"
download_infect "$infect_script"
make_known_hosts "$known_hosts"

echo "mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
echo "host=$HOST"
echo "droplet_id=$DROPLET_ID"
echo "snapshot_id=$SNAPSHOT_ID"
echo "nix_channel=$NIX_CHANNEL"
echo "nixos_infect_commit=$INFECT_COMMIT"
echo "nixos_infect_sha256=$INFECT_SHA256"
echo

echo "droplet_proof:"
doctl compute droplet get "$DROPLET_ID" \
  --format ID,Name,PublicIPv4,PrivateIPv4,Memory,VCPUs,Disk,Region,Image,Status,Tags,Features \
  --no-header

echo
echo "snapshot_proof:"
doctl compute snapshot get "$SNAPSHOT_ID" \
  --format ID,Name,CreatedAt,Regions,ResourceId,ResourceType,MinDiskSize,Size,Tags \
  --no-header

echo
echo "ssh_host_fingerprints:"
ssh-keygen -lf "$known_hosts"

echo
echo "remote_read_only_probe:"
ssh_base "$known_hosts" \
  'set -e
   echo "whoami=$(whoami)"
   echo "hostname=$(hostname)"
   . /etc/os-release
   echo "os=$PRETTY_NAME"
   echo "kernel=$(uname -srmo)"
   command -v nix || echo "nix_bin=absent"
   command -v nixos-rebuild || echo "nixos_rebuild=absent"
   test ! -e /nix && echo "nix_root=absent" || echo "nix_root=present"'

echo
echo "apply_command:"
printf 'scripts/nixos-conversion.sh --apply --confirm-destructive-nixos-conversion --confirm-snapshot-id %s\n' "$SNAPSHOT_ID"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "dry-run complete; remote host was not modified"
  exit 0
fi

if [ "$CONFIRM_CONVERSION" -ne 1 ]; then
  echo "refusing conversion: missing --confirm-destructive-nixos-conversion" >&2
  exit 2
fi

if [ "$CONFIRM_SNAPSHOT_ID" != "$SNAPSHOT_ID" ]; then
  echo "refusing conversion: --confirm-snapshot-id must equal $SNAPSHOT_ID" >&2
  exit 2
fi

if [ "$REBOOT_AFTER_STAGE" -eq 1 ] && [ "$CONFIRM_REBOOT" -ne 1 ]; then
  echo "refusing reboot: pass --confirm-lustrate-reboot with --reboot-after-stage" >&2
  exit 2
fi

echo
echo "staging_remote_files:"
ssh_base "$known_hosts" 'mkdir -p /root/windburn-nixos /etc/nixos'
scp_base "$known_hosts" "$infect_script" "/root/windburn-nixos/nixos-infect"
scp_base "$known_hosts" "$HOST_NIX" "/etc/nixos/windburn-workhorse.nix"

echo
echo "remote_sha256_check:"
ssh_base "$known_hosts" \
  "set -e; actual=\$(sha256sum /root/windburn-nixos/nixos-infect | awk '{print \$1}'); echo \"sha256=\$actual\"; test \"\$actual\" = \"$INFECT_SHA256\"; chmod +x /root/windburn-nixos/nixos-infect"

echo
echo "running_nixos_infect_no_reboot:"
ssh_base "$known_hosts" \
  "bash -lc 'set -o pipefail; PROVIDER=digitalocean NIX_CHANNEL=$NIX_CHANNEL NIXOS_IMPORT=./windburn-workhorse.nix NO_REBOOT=1 bash -x /root/windburn-nixos/nixos-infect 2>&1 | tee /root/windburn-nixos/infect.log'"

echo
echo "stage_complete=1"

if [ "$REBOOT_AFTER_STAGE" -eq 1 ]; then
  echo "rebooting_for_lustrate=1"
  doctl compute droplet-action reboot "$DROPLET_ID" --wait \
    --format ID,Status,Type,StartedAt,CompletedAt,ResourceID,Region \
    --no-header
fi
