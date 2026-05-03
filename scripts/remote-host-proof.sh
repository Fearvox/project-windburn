#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

HOST="${WINDBURN_REMOTE_HOST:-}"
DROPLET_ID="${WINDBURN_DROPLET_ID:-}"
REMOTE_USER="${WINDBURN_REMOTE_USER:-root}"
IDENTITY="${WINDBURN_SSH_IDENTITY:-$HOME/.ssh/id_ed25519}"
OUT=""
DOCTL_PROOF=1

usage() {
  cat <<'USAGE'
Usage: scripts/remote-host-proof.sh [--host IP_OR_DNS] [--droplet-id ID] [--user USER] [--identity PATH] [--out PATH] [--no-doctl]

Runs read-only proof against a selected remote workhorse host:
  - optional DigitalOcean droplet get
  - TCP/22 reachability
  - SSH host-key fingerprints via a temporary known_hosts file
  - strict SSH login with read-only OS, disk, memory, network, and Nix probes

Environment:
  WINDBURN_REMOTE_HOST     remote IP/DNS if --host is omitted
  WINDBURN_DROPLET_ID      DigitalOcean Droplet ID if --droplet-id is omitted
  WINDBURN_REMOTE_USER     defaults to root
  WINDBURN_SSH_IDENTITY    defaults to ~/.ssh/id_ed25519
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="${2:?missing value for --host}"
      shift 2
      ;;
    --droplet-id)
      DROPLET_ID="${2:?missing value for --droplet-id}"
      shift 2
      ;;
    --user)
      REMOTE_USER="${2:?missing value for --user}"
      shift 2
      ;;
    --identity)
      IDENTITY="${2:?missing value for --identity}"
      shift 2
      ;;
    --out)
      OUT="${2:?missing value for --out}"
      shift 2
      ;;
    --no-doctl)
      DOCTL_PROOF=0
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

if [ -z "$HOST" ]; then
  echo "missing remote host; set WINDBURN_REMOTE_HOST or pass --host" >&2
  exit 2
fi

if [ ! -f "$IDENTITY" ]; then
  echo "missing SSH identity: $IDENTITY" >&2
  exit 2
fi

run() {
  printf '+ %s\n' "$*"
  "$@"
}

capture() {
  {
    printf '# Windburn remote host proof\n\n'
    printf 'generated_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'host=%s\n' "$HOST"
    printf 'user=%s\n' "$REMOTE_USER"
    printf 'identity=%s\n\n' "$IDENTITY"

    if [ "$DOCTL_PROOF" -eq 1 ] && [ -n "$DROPLET_ID" ]; then
      run doctl compute droplet get "$DROPLET_ID" \
        --format ID,Name,PublicIPv4,PrivateIPv4,Memory,VCPUs,Disk,Region,Image,VPCUUID,Status,Tags,Features \
        --no-header
      printf '\n'
    fi

    run nc -vz -w 10 "$HOST" 22
    printf '\n'

    known_hosts="$(mktemp)"
    trap 'rm -f "$known_hosts"' EXIT
    ssh-keyscan -4 -T 10 "$HOST" > "$known_hosts" 2>/dev/null
    run ssh-keygen -lf "$known_hosts"
    printf '\n'

    run ssh \
      -i "$IDENTITY" \
      -o BatchMode=yes \
      -o IdentitiesOnly=yes \
      -o UserKnownHostsFile="$known_hosts" \
      -o StrictHostKeyChecking=yes \
      -o ConnectTimeout=20 \
      "$REMOTE_USER@$HOST" \
      'set -e
       echo "whoami=$(whoami)"
       echo "hostname=$(hostname)"
       . /etc/os-release
       echo "os=$PRETTY_NAME"
       echo "kernel=$(uname -srmo)"
       cloud-init status 2>/dev/null | sed "s/^/cloud_init=/" || true
       df -h / | tail -1 | sed "s/^/root_fs=/"
       free -h | sed -n "s/^Mem:/memory=/p"
       echo "cpu_count=$(nproc)"
       ip -brief addr show eth0 || true
       ip -brief addr show eth1 || true
       command -v nix || echo "nix_bin=absent"
       command -v nixos-rebuild || echo "nixos_rebuild=absent"
       test ! -e /nix && echo "nix_root=absent" || echo "nix_root=present"'
  }
}

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  capture | tee "$OUT"
else
  capture
fi
