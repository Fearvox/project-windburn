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
REMOTE_SECRET_PATH="${WINDBURN_REMOTE_CODEX_AUTH:-/srv/windburn/secrets/codex-auth.json}"
REMOTE_ROOT_AUTH_PATH="${WINDBURN_REMOTE_ROOT_CODEX_AUTH:-/root/.codex/auth.json}"
REMOTE_HERMES_AUTH_PATH="${WINDBURN_REMOTE_HERMES_AUTH:-/root/.hermes/auth.json}"
HERMES_GITHUB_REV="${WINDBURN_HERMES_GITHUB_REV:-6f2dab248a6cc8591af46e5deb2dc939c2b43146}"
HERMES_MODEL="${WINDBURN_HERMES_CODEX_MODEL:-gpt-5.5}"
EXPECTED_TEXT="${WINDBURN_HERMES_CODEX_EXPECTED:-WINDBURN_REMOTE_CODEX_PROVIDER_OK}"

APPLY=0
CONFIRM=0

usage() {
  cat <<'USAGE'
Usage: scripts/remote-hermes-codex-smoke.sh [--apply --confirm-remote-hermes-codex-smoke]

Default mode is dry-run. It checks remote NixOS, Nix, Codex CLI auth presence,
and Hermes openai-codex auth presence without making a model call or changing
the remote host.

Apply mode runs pinned Hermes from GitHub through the openai-codex provider and
writes a root-only artifact under /srv/windburn/runs/hermes-codex-smoke.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --confirm-remote-hermes-codex-smoke)
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

if [ "$APPLY" -eq 1 ] && [ "$CONFIRM" -ne 1 ]; then
  echo "refusing Hermes Codex smoke: missing --confirm-remote-hermes-codex-smoke" >&2
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

echo "mode=$([ "$APPLY" -eq 1 ] && echo apply || echo dry-run)"
echo "host=$HOST"
echo "hermes_github_rev=$HERMES_GITHUB_REV"
echo "hermes_model=$HERMES_MODEL"
echo "remote_secret_path=$REMOTE_SECRET_PATH"
echo "remote_root_auth_path=$REMOTE_ROOT_AUTH_PATH"
echo "remote_hermes_auth_path=$REMOTE_HERMES_AUTH_PATH"
echo

remote_script='
set -eu

apply="__APPLY__"
secret_path="__REMOTE_SECRET_PATH__"
root_auth_path="__REMOTE_ROOT_AUTH_PATH__"
hermes_auth_path="__REMOTE_HERMES_AUTH_PATH__"
hermes_rev="__HERMES_GITHUB_REV__"
hermes_model="__HERMES_MODEL__"
expected_text="__EXPECTED_TEXT__"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-hermes-codex-smoke"
run_dir="/srv/windburn/runs/hermes-codex-smoke/$run_id"

json_bool() {
  if [ "$1" = "1" ]; then
    echo true
  else
    echo false
  fi
}

file_status() {
  path="$1"
  if [ -f "$path" ]; then
    echo present
  else
    echo absent
  fi
}

root_auth_status="$(file_status "$root_auth_path")"
secret_auth_status="$(file_status "$secret_path")"
hermes_auth_status="$(file_status "$hermes_auth_path")"
hermes_auth_has_openai_codex=false
hermes_auth_access_token_length=0
hermes_auth_has_refresh_token=false
if [ "$hermes_auth_status" = "present" ]; then
  hermes_auth_has_openai_codex="$(jq -r '\''(.providers["openai-codex"]? != null) | tostring'\'' "$hermes_auth_path" 2>/dev/null || echo false)"
  hermes_auth_access_token_length="$(jq -r '\''((.providers["openai-codex"].tokens.access_token? // "") | tostring | length)'\'' "$hermes_auth_path" 2>/dev/null || echo 0)"
  hermes_auth_has_refresh_token="$(jq -r '\''(((.providers["openai-codex"].tokens.refresh_token? // "") | tostring | length) > 0) | tostring'\'' "$hermes_auth_path" 2>/dev/null || echo false)"
fi
hostname_value="$(hostname)"
system_state="$(systemctl is-system-running || true)"
failed_units="$(systemctl --failed --no-legend --plain | sed "/^$/d" | wc -l | tr -d " ")"
nix_path="$(command -v nix || true)"

verdict=PASS
reason=REMOTE_CODEX_AUTH_PRESENT_READ_ONLY
version_exit_code=-1
smoke_exit_code=-1
output_match=0
stdout_bytes=0
stderr_bytes=0
observed_text=""
artifact_path=""

if [ -z "$nix_path" ]; then
  verdict=FLAG
  reason=REMOTE_NIX_MISSING
elif [ "$root_auth_status" != "present" ]; then
  verdict=FLAG
  reason=REMOTE_CODEX_CLI_AUTH_MISSING
elif [ "$hermes_auth_status" != "present" ]; then
  verdict=FLAG
  reason=REMOTE_HERMES_CODEX_AUTH_MISSING
elif [ "$hermes_auth_has_openai_codex" != "true" ] || [ "$hermes_auth_access_token_length" -le 0 ] || [ "$hermes_auth_has_refresh_token" != "true" ]; then
  verdict=FLAG
  reason=REMOTE_HERMES_CODEX_AUTH_INVALID
fi

if [ "$apply" = "1" ]; then
  install -d -o root -g root -m 0700 "$run_dir"
  artifact_path="$run_dir/result.json"

  if [ "$verdict" = "PASS" ]; then
    version_stdout="$run_dir/hermes-version.stdout"
    version_stderr="$run_dir/hermes-version.stderr"
    smoke_stdout="$run_dir/smoke.stdout"
    smoke_stderr="$run_dir/smoke.stderr"

    if timeout 600 nix run "github:NousResearch/hermes-agent/$hermes_rev" -- --version >"$version_stdout" 2>"$version_stderr"; then
      version_exit_code=0
    else
      version_exit_code=$?
      verdict=FLAG
      reason=HERMES_VERSION_FAILED
    fi

    if [ "$verdict" = "PASS" ]; then
      prompt="Reply exactly: $expected_text"
      if timeout 240 nix run "github:NousResearch/hermes-agent/$hermes_rev" -- --provider openai-codex --model "$hermes_model" --ignore-rules -z "$prompt" >"$smoke_stdout" 2>"$smoke_stderr"; then
        smoke_exit_code=0
      else
        smoke_exit_code=$?
      fi

      stdout_bytes="$(wc -c < "$smoke_stdout" | tr -d " ")"
      stderr_bytes="$(wc -c < "$smoke_stderr" | tr -d " ")"
      observed_text="$(tr -d "\r" < "$smoke_stdout" | sed -e "s/[[:space:]]*$//")"

      if [ "$smoke_exit_code" -ne 0 ]; then
        verdict=FLAG
        reason="HERMES_CODEX_SMOKE_EXIT_$smoke_exit_code"
      elif [ "$observed_text" = "$expected_text" ]; then
        output_match=1
        verdict=PASS
        reason=HERMES_CODEX_PROVIDER_OK
      else
        verdict=FLAG
        reason=HERMES_CODEX_OUTPUT_MISMATCH
      fi
    fi

    chmod 0600 "$run_dir"/* 2>/dev/null || true
  fi
fi

result_json="$(jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg run_id "$run_id" \
  --arg hostname "$hostname_value" \
  --arg verdict "$verdict" \
  --arg reason "$reason" \
  --arg system_state "$system_state" \
  --arg failed_units "$failed_units" \
  --arg nix_path "$nix_path" \
  --arg hermes_source "github:NousResearch/hermes-agent" \
  --arg hermes_rev "$hermes_rev" \
  --arg hermes_model "$hermes_model" \
  --arg root_auth_status "$root_auth_status" \
  --arg secret_auth_status "$secret_auth_status" \
  --arg hermes_auth_status "$hermes_auth_status" \
  --arg hermes_auth_has_openai_codex "$hermes_auth_has_openai_codex" \
  --argjson hermes_auth_access_token_length "$hermes_auth_access_token_length" \
  --arg hermes_auth_has_refresh_token "$hermes_auth_has_refresh_token" \
  --arg root_auth_path "$root_auth_path" \
  --arg secret_path "$secret_path" \
  --arg hermes_auth_path "$hermes_auth_path" \
  --argjson version_exit_code "$version_exit_code" \
  --argjson smoke_exit_code "$smoke_exit_code" \
  --argjson output_match "$(json_bool "$output_match")" \
  --arg expected_text "$expected_text" \
  --arg observed_text "$observed_text" \
  --argjson stdout_bytes "$stdout_bytes" \
  --argjson stderr_bytes "$stderr_bytes" \
  --arg artifact_path "$artifact_path" \
  "{
    schema_version: 1,
    generated_at_utc: \$generated_at,
    run_id: \$run_id,
    hostname: \$hostname,
    verdict: \$verdict,
    reason: \$reason,
    remote_health: {
      system_state: \$system_state,
      failed_units: (\$failed_units | tonumber),
      nix_path: (if (\$nix_path | length) == 0 then null else \$nix_path end)
    },
    hermes: {
      source: \$hermes_source,
      rev: \$hermes_rev,
      model: \$hermes_model,
      version_exit_code: \$version_exit_code,
      smoke_exit_code: \$smoke_exit_code,
      output_match: \$output_match,
      expected_text: \$expected_text,
      observed_text: (if \$output_match then \$observed_text else null end),
      stdout_bytes: \$stdout_bytes,
      stderr_bytes: \$stderr_bytes
    },
    codex_auth: {
      root: { path: \$root_auth_path, status: \$root_auth_status },
      secret_copy: { path: \$secret_path, status: \$secret_auth_status }
    },
    hermes_auth: {
      path: \$hermes_auth_path,
      status: \$hermes_auth_status,
      has_openai_codex_provider: (\$hermes_auth_has_openai_codex == \"true\"),
      openai_codex_access_token_length: \$hermes_auth_access_token_length,
      has_openai_codex_refresh_token: (\$hermes_auth_has_refresh_token == \"true\")
    },
    artifact_path: (if (\$artifact_path | length) == 0 then null else \$artifact_path end),
    repair_card: (if \$verdict == \"PASS\" then null else {
      id: \"REMOTE_HERMES_CODEX_REPAIR\",
      action: \"Run scripts/remote-codex-auth-sync.sh --apply --confirm-remote-codex-auth-sync, then rerun scripts/remote-hermes-codex-smoke.sh --apply --confirm-remote-hermes-codex-smoke.\"
    } end)
  }")"

if [ "$apply" = "1" ]; then
  printf "%s\n" "$result_json" | tee "$artifact_path"
  echo "artifact=$artifact_path"
else
  printf "%s\n" "$result_json"
  echo "dry-run complete; no model call and no artifact written"
fi
'

remote_script="${remote_script/__APPLY__/$APPLY}"
remote_script="${remote_script/__REMOTE_SECRET_PATH__/$REMOTE_SECRET_PATH}"
remote_script="${remote_script/__REMOTE_ROOT_AUTH_PATH__/$REMOTE_ROOT_AUTH_PATH}"
remote_script="${remote_script/__REMOTE_HERMES_AUTH_PATH__/$REMOTE_HERMES_AUTH_PATH}"
remote_script="${remote_script/__HERMES_GITHUB_REV__/$HERMES_GITHUB_REV}"
remote_script="${remote_script/__HERMES_MODEL__/$HERMES_MODEL}"
remote_script="${remote_script/__EXPECTED_TEXT__/$EXPECTED_TEXT}"

ssh_base "bash -lc $(printf '%q' "$remote_script")"
