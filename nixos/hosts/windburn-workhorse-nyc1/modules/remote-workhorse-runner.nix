{ pkgs, ... }:

let
  windburnRunnerStatus = pkgs.writeShellApplication {
    name = "windburn-runner-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.gnused
      pkgs.jq
      pkgs.systemd
      pkgs.tmux
    ];
    text = ''
      set -eu

      out_dir=/srv/windburn/evidence/runner
      mkdir -p "$out_dir"

      bool_file() {
        if [ -f "$1" ]; then
          printf '%s' true
        else
          printf '%s' false
        fi
      }

      generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      hostname="$(cat /proc/sys/kernel/hostname)"
      system_state="$(systemctl is-system-running || true)"
      failed_units="$(systemctl --failed --no-legend --plain | sed '/^$/d' | wc -l | tr -d ' ')"
      health_present="$(bool_file /srv/windburn/evidence/health/current.json)"
      health_generated_at="unknown"
      if [ "$health_present" = true ]; then
        health_generated_at="$(jq -r '.generated_at_utc // "unknown"' /srv/windburn/evidence/health/current.json 2>/dev/null || printf '%s' unknown)"
      fi

      codex_auth_present=false
      if [ -f /srv/windburn/secrets/codex-auth.json ] || [ -f /root/.codex/auth.json ]; then
        codex_auth_present=true
      fi
      hermes_auth_present="$(bool_file /root/.hermes/auth.json)"
      provider_env_present="$(bool_file /srv/windburn/secrets/provider.env)"

      tmux_sessions="$(tmux ls 2>/dev/null || true)"
      tmux_session_count="$(printf '%s\n' "$tmux_sessions" | sed '/^$/d' | wc -l | tr -d ' ')"
      tmux_session_present=false
      if [ "$tmux_session_count" -gt 0 ]; then
        tmux_session_present=true
      fi

      latest_smoke_file="$(
        if [ -d /srv/windburn/runs/hermes-codex-smoke ]; then
          find /srv/windburn/runs/hermes-codex-smoke -mindepth 2 -maxdepth 2 -type f -name result.json 2>/dev/null | sort | tail -n 1
        fi
      )"
      latest_smoke_run_id="none"
      latest_smoke_verdict="UNKNOWN"
      latest_smoke_reason="missing_hermes_codex_smoke"
      latest_smoke_generated_at="unknown"
      if [ -n "$latest_smoke_file" ]; then
        latest_smoke_run_id="$(basename "$(dirname "$latest_smoke_file")")"
        latest_smoke_verdict="$(jq -r '.verdict // "UNKNOWN"' "$latest_smoke_file" 2>/dev/null || printf '%s' UNKNOWN)"
        latest_smoke_reason="$(jq -r '.reason // "unknown"' "$latest_smoke_file" 2>/dev/null || printf '%s' unknown)"
        latest_smoke_generated_at="$(jq -r '.generated_at_utc // "unknown"' "$latest_smoke_file" 2>/dev/null || printf '%s' unknown)"
      fi

      runner_status=PASS
      runner_reason=runner_foundation_ready
      if [ "$system_state" != running ]; then
        runner_status=FLAG
        runner_reason=system_not_running
      elif [ "$failed_units" -ne 0 ]; then
        runner_status=FLAG
        runner_reason=failed_units_present
      elif [ "$codex_auth_present" != true ]; then
        runner_status=FLAG
        runner_reason=codex_auth_missing
      elif [ "$latest_smoke_verdict" != PASS ]; then
        runner_status=FLAG
        runner_reason=latest_hermes_codex_smoke_not_pass
      fi

      tmp="$out_dir/current.json.tmp"
      jq -n \
        --arg generated_at "$generated_at" \
        --arg hostname "$hostname" \
        --arg runner_status "$runner_status" \
        --arg runner_reason "$runner_reason" \
        --arg system_state "$system_state" \
        --argjson failed_units "$failed_units" \
        --arg health_present "$health_present" \
        --arg health_generated_at "$health_generated_at" \
        --arg codex_auth_present "$codex_auth_present" \
        --arg hermes_auth_present "$hermes_auth_present" \
        --arg provider_env_present "$provider_env_present" \
        --arg tmux_session_present "$tmux_session_present" \
        --argjson tmux_session_count "$tmux_session_count" \
        --arg latest_smoke_run_id "$latest_smoke_run_id" \
        --arg latest_smoke_verdict "$latest_smoke_verdict" \
        --arg latest_smoke_reason "$latest_smoke_reason" \
        --arg latest_smoke_generated_at "$latest_smoke_generated_at" \
        '{
          schema_version: 1,
          generated_at_utc: $generated_at,
          runner_id: "windburn-workhorse-runner-status-v0",
          runner_kind: "read-only-evidence",
          hostname: $hostname,
          status: $runner_status,
          reason: $runner_reason,
          system_state: $system_state,
          failed_units: $failed_units,
          tmux: {
            session_present: ($tmux_session_present == "true"),
            session_count: $tmux_session_count
          },
          credentials: {
            codex_auth_present: ($codex_auth_present == "true"),
            hermes_auth_present: ($hermes_auth_present == "true"),
            provider_env_present: ($provider_env_present == "true")
          },
          health: {
            present: ($health_present == "true"),
            generated_at_utc: $health_generated_at
          },
          latest_hermes_codex_smoke: {
            run_id: $latest_smoke_run_id,
            verdict: $latest_smoke_verdict,
            reason: $latest_smoke_reason,
            generated_at_utc: $latest_smoke_generated_at
          },
          capabilities: [
            "read-only-status",
            "timer-evidence",
            "hermes-codex-smoke-readback"
          ],
          remote_mutation: false,
          secret_values_recorded: false,
          redacted_public_safe: true
        }' > "$tmp"

      mv "$tmp" "$out_dir/current.json"
      chown -R windburn:windburn /srv/windburn/evidence
      chmod 0755 /srv/windburn/evidence /srv/windburn/evidence/runner
      chmod 0644 "$out_dir/current.json"
      cat "$out_dir/current.json"
    '';
  };
in
{
  environment.systemPackages = [
    windburnRunnerStatus
  ];

  systemd.tmpfiles.rules = [
    "d /srv/windburn/evidence/runner 0755 windburn windburn -"
  ];

  systemd.services.windburn-runner-status = {
    description = "Write Windburn remote workhorse runner evidence";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      PrivateTmp = false;
      ProtectHome = "read-only";
      ProtectSystem = "strict";
      ReadOnlyPaths = [
        "/srv/windburn/runs"
        "/srv/windburn/secrets"
      ];
      ReadWritePaths = [
        "/srv/windburn/evidence"
      ];
    };
    script = ''
      exec ${windburnRunnerStatus}/bin/windburn-runner-status
    '';
  };

  systemd.timers.windburn-runner-status = {
    description = "Refresh Windburn remote workhorse runner evidence";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "90s";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Unit = "windburn-runner-status.service";
    };
  };
}
