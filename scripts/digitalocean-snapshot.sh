#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

DROPLET_ID="${WINDBURN_DROPLET_ID:-568689911}"
SNAPSHOT_NAME="${WINDBURN_SNAPSHOT_NAME:-}"
APPLY=0
CONFIRM=0
WAIT_FLAG="--wait"

usage() {
  cat <<'USAGE'
Usage: scripts/digitalocean-snapshot.sh [--droplet-id ID] [--name NAME] [--apply --confirm-billable-snapshot] [--no-wait]

Default mode is dry-run. It proves the selected Droplet and prints the exact
snapshot command without creating billable storage.

Mutation requires both:
  --apply
  --confirm-billable-snapshot

Environment:
  WINDBURN_DROPLET_ID       defaults to the current workhorse candidate
  WINDBURN_SNAPSHOT_NAME    optional snapshot name override
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --droplet-id)
      DROPLET_ID="${2:?missing value for --droplet-id}"
      shift 2
      ;;
    --name)
      SNAPSHOT_NAME="${2:?missing value for --name}"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-billable-snapshot)
      CONFIRM=1
      shift
      ;;
    --no-wait)
      WAIT_FLAG=""
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

if [ -z "$DROPLET_ID" ]; then
  echo "missing Droplet ID; set WINDBURN_DROPLET_ID or pass --droplet-id" >&2
  exit 2
fi

if [ -z "$SNAPSHOT_NAME" ]; then
  SNAPSHOT_NAME="windburn-workhorse-nyc1-base-$(date -u +%Y%m%d-%H%MZ)"
fi

echo "droplet_proof:"
doctl compute droplet get "$DROPLET_ID" \
  --format ID,Name,PublicIPv4,PrivateIPv4,Memory,VCPUs,Disk,Region,Image,Status,Tags,Features \
  --no-header

echo
echo "snapshot_command:"
printf 'doctl compute droplet-action snapshot %s --snapshot-name %s %s --format ID,Status,Type,StartedAt,CompletedAt,ResourceID,Region --no-header\n' \
  "$DROPLET_ID" "$SNAPSHOT_NAME" "$WAIT_FLAG"

if [ "$APPLY" -ne 1 ]; then
  echo
  echo "mode=dry-run"
  echo "no snapshot created"
  exit 0
fi

if [ "$CONFIRM" -ne 1 ]; then
  echo "refusing mutation: pass --confirm-billable-snapshot with --apply" >&2
  exit 2
fi

echo
echo "mode=apply"
doctl compute droplet-action snapshot "$DROPLET_ID" \
  --snapshot-name "$SNAPSHOT_NAME" \
  $WAIT_FLAG \
  --format ID,Status,Type,StartedAt,CompletedAt,ResourceID,Region \
  --no-header

echo
echo "snapshot_inventory:"
doctl compute snapshot list \
  --format ID,Name,CreatedAt,ResourceId,ResourceType,MinDiskSize,Size,Tags \
  --no-header
