#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

HOST="${HERMES_DROPLET_HOST:-137.184.104.26}"
REMOTE_USER="${WINDBURN_REMOTE_USER:-root}"
IDENTITY="${WINDBURN_SSH_IDENTITY:-$HOME/.ssh/id_ed25519}"
SSH_TIMEOUT="${WINDBURN_SSH_TIMEOUT:-12}"
FIXED_SESSION="${HERMES_TMUX_SESSION:-windburn-hermes-runtime}"
APPLY_UPDATE=0
ENSURE_TMUX=0
CONFIRM=0
OUT=""

usage() {
  cat <<'USAGE'
Usage: scripts/hermes-maintenance.sh [--out PATH] [--ensure-tmux] [--apply-update --confirm-hermes-maintenance]

Default mode is read-only inspect. It captures Hermes version, update delta,
local-ahead commit state, service state, and tmux runtime-entry state.

Mutation requires explicit flags:
  --ensure-tmux --confirm-hermes-maintenance
  --apply-update --confirm-hermes-maintenance

Update mode protects the current local Hermes commit with a backup branch and
tag, runs `hermes update --backup --yes`, then attempts to cherry-pick local
ahead commits back onto the updated main. If cherry-pick conflicts, it aborts
the cherry-pick and reports the backup ref.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      OUT="${2:?missing value for --out}"
      shift 2
      ;;
    --ensure-tmux)
      ENSURE_TMUX=1
      shift
      ;;
    --apply-update)
      APPLY_UPDATE=1
      shift
      ;;
    --confirm-hermes-maintenance)
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

if { [ "$APPLY_UPDATE" -eq 1 ] || [ "$ENSURE_TMUX" -eq 1 ]; } && [ "$CONFIRM" -ne 1 ]; then
  echo "refusing remote mutation: pass --confirm-hermes-maintenance" >&2
  exit 2
fi

if [ ! -f "$IDENTITY" ]; then
  echo "missing SSH identity: $IDENTITY" >&2
  exit 2
fi

generated_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
known_hosts="$(mktemp)"
cleanup() {
  rm -f "$known_hosts"
}
trap cleanup EXIT

ssh-keyscan -4 -T "$SSH_TIMEOUT" "$HOST" > "$known_hosts" 2>/dev/null
test -s "$known_hosts"

remote_output="$(
  ssh \
    -i "$IDENTITY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    -o ConnectTimeout="$SSH_TIMEOUT" \
    "$REMOTE_USER@$HOST" \
    'bash -s' -- "$APPLY_UPDATE" "$ENSURE_TMUX" "$FIXED_SESSION" <<'REMOTE'
set -u
apply_update="$1"
ensure_tmux="$2"
fixed_session="$3"
repo="/root/.hermes/hermes-agent"
ts="$(date -u +%Y%m%dT%H%M%SZ)"

echo "host=$(hostname)"
echo "generated_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "repo=$repo"
echo "apply_update=$apply_update"
echo "ensure_tmux=$ensure_tmux"
echo "fixed_session=$fixed_session"
echo "hermes_bin=$(command -v hermes || true)"
hermes --version 2>&1 | sed 's/^/before_hermes_version=/'
hermes update --check 2>&1 | sed 's/^/before_update_check=/'

if [ ! -d "$repo/.git" ]; then
  echo "verdict=BLOCK"
  echo "reason=missing_hermes_git_repo"
  exit 0
fi

git -C "$repo" fetch origin main >/dev/null 2>&1 || true
before_head="$(git -C "$repo" rev-parse --short=12 HEAD 2>/dev/null || true)"
before_origin="$(git -C "$repo" rev-parse --short=12 origin/main 2>/dev/null || true)"
ahead_commits="$(git -C "$repo" rev-list --reverse origin/main..HEAD 2>/dev/null || true)"
ahead_count="$(printf '%s\n' "$ahead_commits" | awk 'NF { n++ } END { print n+0 }')"
behind_count="$(git -C "$repo" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"
echo "before_head=$before_head"
echo "before_origin_main=$before_origin"
echo "before_ahead_count=$ahead_count"
echo "before_behind_count=$behind_count"
git -C "$repo" status --short --branch 2>&1 | sed 's/^/before_git_status=/'
git -C "$repo" log --oneline --decorate --left-right --cherry-pick HEAD...origin/main 2>&1 | head -80 | sed 's/^/delta_log=/'
git -C "$repo" branch --list 'windburn/pre-update-*' --sort=-committerdate 2>/dev/null | head -5 | sed 's/^[* ]*//; s/^/backup_branch_seen=/'
git -C "$repo" tag --list 'windburn-pre-update-*' --sort=-creatordate 2>/dev/null | head -5 | sed 's/^/backup_tag_seen=/'
find /root/.hermes/backups -maxdepth 1 -type f -name 'pre-update-*.zip' -printf '%T@ %p %s\n' 2>/dev/null | sort -rn | head -5 | awk '{ size=$3; $1=""; $3=""; sub(/^  /,""); print "backup_zip_seen="$0" bytes="size }'

backup_branch=""
backup_tag=""
update_exit=0
cherry_pick_status="not_attempted"

if [ "$apply_update" = "1" ]; then
  backup_branch="windburn/pre-update-$ts"
  backup_tag="windburn-pre-update-$ts"
  git -C "$repo" branch "$backup_branch" HEAD
  git -C "$repo" tag "$backup_tag" HEAD
  echo "backup_branch=$backup_branch"
  echo "backup_tag=$backup_tag"

  if hermes update --backup --yes 2>&1 | sed 's/^/hermes_update=/' ; then
    update_exit=0
  else
    update_exit=$?
  fi
  echo "update_exit=$update_exit"

  if [ "$update_exit" -eq 0 ] && [ -n "$ahead_commits" ]; then
    cherry_pick_status="clean"
    for commit in $ahead_commits; do
      if cherry_pick_output="$(git -C "$repo" -c user.name="Windburn Agent" -c user.email="windburn-agent@local" cherry-pick "$commit" 2>&1)"; then
        printf '%s\n' "$cherry_pick_output" | sed "s/^/cherry_pick_${commit}=/"
        :
      else
        printf '%s\n' "$cherry_pick_output" | sed "s/^/cherry_pick_${commit}=/"
        cherry_pick_status="conflict"
        git -C "$repo" cherry-pick --abort >/dev/null 2>&1 || true
        break
      fi
    done
  fi

  systemctl restart hermes-gateway.service 2>&1 | sed 's/^/gateway_restart=/' || true
fi

if [ "$ensure_tmux" = "1" ]; then
  if command -v tmux >/dev/null 2>&1; then
    if tmux has-session -t "$fixed_session" 2>/dev/null; then
      echo "tmux_entry=already_present"
    else
      tmux new-session -d -s "$fixed_session" -n shell -c "$repo"
      tmux new-window -t "$fixed_session" -n gateway-log "journalctl -fu hermes-gateway.service"
      tmux new-window -t "$fixed_session" -n health "while true; do clear; date -u; echo; hermes --version; echo; systemctl --no-pager --plain status hermes-gateway.service | sed -n '1,22p'; sleep 15; done"
      tmux select-window -t "$fixed_session:shell"
      echo "tmux_entry=created"
    fi
  else
    echo "tmux_entry=missing_tmux_binary"
  fi
fi

hermes --version 2>&1 | sed 's/^/after_hermes_version=/'
hermes update --check 2>&1 | sed 's/^/after_update_check=/'
git -C "$repo" status --short --branch 2>&1 | sed 's/^/after_git_status=/'
git -C "$repo" rev-parse --short=12 HEAD 2>&1 | sed 's/^/after_head=/'
echo "hermes_gateway_service=$(systemctl is-active hermes-gateway.service 2>/dev/null || true)"
echo "do_agent_service=$(systemctl is-active do-agent.service 2>/dev/null || true)"
echo "droplet_agent_service=$(systemctl is-active droplet-agent.service 2>/dev/null || true)"
echo "tailscaled_service=$(systemctl is-active tailscaled.service 2>/dev/null || true)"
echo "hermes_chat_count=$(pgrep -fc 'hermes chat' 2>/dev/null || true)"
echo "research_vault_mcp_count=$(pgrep -fc 'research-vault-mcp' 2>/dev/null || true)"
echo "multica_daemon_count=$(pgrep -fc 'multica daemon' 2>/dev/null || true)"
echo "recent_gateway_warning_count=$(journalctl -u hermes-gateway.service --since '20 min ago' --no-pager 2>/dev/null | grep -Eic 'warn|warning|closed|error' || true)"
if command -v tmux >/dev/null 2>&1; then
  if tmux has-session -t "$fixed_session" 2>/dev/null; then
    echo "fixed_tmux_session=present"
  else
    echo "fixed_tmux_session=missing"
  fi
  tmux ls 2>&1 | sed 's/^/tmux_session=/'
else
  echo "fixed_tmux_session=missing"
fi
echo "cherry_pick_status=$cherry_pick_status"
REMOTE
)"

flags=()
grep -q '^hermes_gateway_service=active$' <<<"$remote_output" || flags+=("hermes-gateway.service not active after maintenance")
grep -q '^fixed_tmux_session=present$' <<<"$remote_output" || flags+=("fixed tmux session missing after maintenance")
if grep -q '^update_exit=[1-9]' <<<"$remote_output"; then
  flags+=("hermes update exited non-zero")
fi
if grep -q '^cherry_pick_status=conflict$' <<<"$remote_output"; then
  flags+=("local ahead commit cherry-pick conflicted; backup ref preserved")
fi
if awk -F= '$1 == "after_update_check" && /Update available/ { found=1 } END { exit found ? 0 : 1 }' <<<"$remote_output" && [ "$APPLY_UPDATE" -eq 1 ]; then
  flags+=("Hermes still reports update available after update")
fi
if awk -F= '$1 == "after_git_status" && $2 ~ /^[ MADRCU?!]/ { dirty=1 } END { exit dirty ? 0 : 1 }' <<<"$remote_output"; then
  flags+=("Hermes git tree is dirty after maintenance")
fi

overall="PASS"
if [ "${#flags[@]}" -gt 0 ]; then
  overall="FLAG"
fi

emit_flags() {
  if [ "${#flags[@]}" -eq 0 ]; then
    printf -- '- none\n'
    return
  fi
  local item
  for item in "${flags[@]}"; do
    printf -- '- %s\n' "$item"
  done
}

capture() {
  cat <<REPORT
# Hermes Maintenance

Generated: \`$generated_utc\`

Target: \`$HOST\`

Mode: update=\`$APPLY_UPDATE\`, ensure_tmux=\`$ENSURE_TMUX\`

VERDICT: \`$overall\`

## Flags

$(emit_flags)

## Evidence

\`\`\`text
$remote_output
\`\`\`

## Rerun

\`\`\`sh
scripts/hermes-maintenance.sh --out docs/remote-workhorse/preflight/HERMES_MAINTENANCE.md
scripts/hermes-maintenance.sh --apply-update --ensure-tmux --confirm-hermes-maintenance --out docs/remote-workhorse/preflight/HERMES_MAINTENANCE.md
\`\`\`
REPORT
}

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  capture | tee "$OUT"
else
  capture
fi
