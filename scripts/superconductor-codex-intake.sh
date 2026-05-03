#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
SUPERCONDUCTOR_PROJECTS_DIR="${SUPERCONDUCTOR_PROJECTS_DIR:-$HOME/superconductor/projects}"

if [ -f "$ROOT/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.local"
  set +a
fi

REMOTE_HOST="${WINDBURN_REMOTE_HOST:-24.144.113.25}"
DROPLET_ID="${WINDBURN_DROPLET_ID:-568689911}"
REMOTE_USER="${WINDBURN_REMOTE_USER:-root}"

root_real="$(cd "$ROOT" && pwd -P)"
binding="missing"
binding_path=""

if [ -d "$SUPERCONDUCTOR_PROJECTS_DIR" ]; then
  case "$root_real" in
    "$SUPERCONDUCTOR_PROJECTS_DIR"/*)
      binding="inside"
      binding_path="$root_real"
      ;;
  esac

  if [ "$binding" = "missing" ]; then
    for candidate in "$SUPERCONDUCTOR_PROJECTS_DIR"/*; do
      [ -e "$candidate" ] || continue
      candidate_real="$(cd "$candidate" 2>/dev/null && pwd -P || true)"
      if [ "$candidate_real" = "$root_real" ]; then
        binding="linked"
        binding_path="$candidate"
        break
      fi
    done
  fi
fi

branch="$(git -C "$ROOT" branch --show-current 2>/dev/null || printf 'unknown')"
remote_origin="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
status_short="$(git -C "$ROOT" status --short 2>/dev/null || true)"

if [ -z "$remote_origin" ]; then
  remote_origin="missing"
fi

status_summary="dirty"
if [ -z "$status_short" ]; then
  status_summary="clean"
fi

env_state() {
  key="$1"
  eval "value=\${$key:-}"
  if [ -n "$value" ]; then
    printf '%s=present\n' "$key"
  else
    printf '%s=absent\n' "$key"
  fi
}

file_state() {
  path="$1"
  label="$2"
  if [ -f "$ROOT/$path" ]; then
    printf '%s=%s\n' "$label" "$path"
  else
    printf '%s=missing:%s\n' "$label" "$path"
  fi
}

verdict="PASS"
next_action="Launch Superconductor with repo anchor $ROOT and run scripts/check.sh before accepting work."
if [ "$binding" = "missing" ]; then
  verdict="FLAG"
  next_action="Attach or link $ROOT in Superconductor; do not duplicate the repo unless the operator chooses a new worktree."
fi

cat <<REPORT
SUPERCONDUCTOR_CODEX_INTAKE
generated_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
repo_anchor=$ROOT
repo_realpath=$root_real
branch=$branch
remote_origin=$remote_origin
git_status=$status_summary
superconductor_projects_dir=$SUPERCONDUCTOR_PROJECTS_DIR
superconductor_binding=$binding
superconductor_binding_path=${binding_path:-none}
remote_host=$REMOTE_HOST
droplet_id=$DROPLET_ID
remote_user=$REMOTE_USER
remote_mutation_allowed=false
$(env_state WINDBURN_REMOTE_HOST)
$(env_state WINDBURN_DROPLET_ID)
$(env_state WINDBURN_REMOTE_USER)
$(env_state WINDBURN_SSH_IDENTITY)
$(file_state AGENTS.md agent_contract)
$(file_state README.md public_readme)
$(file_state docs/superconductor-codex-intake.md intake_doc)
$(file_state config/codex-profile.example.toml codex_profile)
$(file_state config/multica-workbench-codex-profile.example.toml workbench_codex_profile)
first_safe_commands=scripts/superconductor-codex-intake.sh;scripts/check.sh;scripts/remote-host-proof.sh
operator_call_conditions=remote_mutation;secret_sync;provider_smoke_apply;nixos_rebuild_apply;destructive_cleanup
next_action=$next_action
verdict=$verdict
REPORT

if [ -n "$status_short" ]; then
  printf '\ngit_status_short:\n%s\n' "$status_short"
fi
