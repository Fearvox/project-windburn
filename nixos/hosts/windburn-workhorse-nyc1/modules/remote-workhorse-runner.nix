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
      codex_runtime_present="$(bool_file /srv/windburn/evidence/codex-runtime/current.json)"
      codex_runtime_status=UNKNOWN
      codex_runtime_reason=missing_codex_runtime_evidence
      codex_command_present=false
      codex_version_status=UNKNOWN
      codex_fixed_session_present=false
      codex_window_present=false
      codex_pane_alive=false
      codex_process_count=0
      if [ "$codex_runtime_present" = true ]; then
        codex_runtime_status="$(jq -r '.status // "UNKNOWN"' /srv/windburn/evidence/codex-runtime/current.json 2>/dev/null || printf '%s' UNKNOWN)"
        codex_runtime_reason="$(jq -r '.reason // "unknown"' /srv/windburn/evidence/codex-runtime/current.json 2>/dev/null || printf '%s' unknown)"
        codex_command_present="$(jq -r '(.codex.command_present // false) | tostring' /srv/windburn/evidence/codex-runtime/current.json 2>/dev/null || printf '%s' false)"
        codex_version_status="$(jq -r '.codex.version_probe.status // "UNKNOWN"' /srv/windburn/evidence/codex-runtime/current.json 2>/dev/null || printf '%s' UNKNOWN)"
        codex_fixed_session_present="$(jq -r '(.lane.fixed_session_present // false) | tostring' /srv/windburn/evidence/codex-runtime/current.json 2>/dev/null || printf '%s' false)"
        codex_window_present="$(jq -r '(.lane.codex_window_present // false) | tostring' /srv/windburn/evidence/codex-runtime/current.json 2>/dev/null || printf '%s' false)"
        codex_pane_alive="$(jq -r '(.lane.pane_alive // false) | tostring' /srv/windburn/evidence/codex-runtime/current.json 2>/dev/null || printf '%s' false)"
        codex_process_count="$(jq -r '(.lane.process_count // 0) | tostring' /srv/windburn/evidence/codex-runtime/current.json 2>/dev/null || printf '%s' 0)"
      fi
      hermes_runtime_present="$(bool_file /srv/windburn/evidence/hermes-runtime/current.json)"
      hermes_runtime_status=UNKNOWN
      hermes_runtime_reason=missing_hermes_runtime_evidence
      hermes_command_present=false
      uv_command_present=false
      if [ "$hermes_runtime_present" = true ]; then
        hermes_runtime_status="$(jq -r '.status // "UNKNOWN"' /srv/windburn/evidence/hermes-runtime/current.json 2>/dev/null || printf '%s' UNKNOWN)"
        hermes_runtime_reason="$(jq -r '.reason // "unknown"' /srv/windburn/evidence/hermes-runtime/current.json 2>/dev/null || printf '%s' unknown)"
        hermes_command_present="$(jq -r '(.hermes.command_present // false) | tostring' /srv/windburn/evidence/hermes-runtime/current.json 2>/dev/null || printf '%s' false)"
        uv_command_present="$(jq -r '(.uv.command_present // false) | tostring' /srv/windburn/evidence/hermes-runtime/current.json 2>/dev/null || printf '%s' false)"
      fi
      hermes_yolo_present="$(bool_file /srv/windburn/evidence/hermes-yolo/current.json)"
      hermes_yolo_status=UNKNOWN
      hermes_yolo_reason=missing_hermes_yolo_evidence
      hermes_yolo_session_present=false
      hermes_yolo_window_present=false
      hermes_yolo_pane_alive=false
      hermes_yolo_process_count=0
      hermes_yolo_ensured_rev_matches=false
      if [ "$hermes_yolo_present" = true ]; then
        hermes_yolo_status="$(jq -r '.status // "UNKNOWN"' /srv/windburn/evidence/hermes-yolo/current.json 2>/dev/null || printf '%s' UNKNOWN)"
        hermes_yolo_reason="$(jq -r '.reason // "unknown"' /srv/windburn/evidence/hermes-yolo/current.json 2>/dev/null || printf '%s' unknown)"
        hermes_yolo_session_present="$(jq -r '(.lane.fixed_session_present // false) | tostring' /srv/windburn/evidence/hermes-yolo/current.json 2>/dev/null || printf '%s' false)"
        hermes_yolo_window_present="$(jq -r '(.lane.yolo_window_present // false) | tostring' /srv/windburn/evidence/hermes-yolo/current.json 2>/dev/null || printf '%s' false)"
        hermes_yolo_pane_alive="$(jq -r '(.lane.pane_alive // false) | tostring' /srv/windburn/evidence/hermes-yolo/current.json 2>/dev/null || printf '%s' false)"
        hermes_yolo_process_count="$(jq -r '(.lane.yolo_process_count // 0) | tostring' /srv/windburn/evidence/hermes-yolo/current.json 2>/dev/null || printf '%s' 0)"
        hermes_yolo_ensured_rev_matches="$(jq -r '(.lane.ensured_rev_matches // false) | tostring' /srv/windburn/evidence/hermes-yolo/current.json 2>/dev/null || printf '%s' false)"
      fi
      herdr_present="$(bool_file /srv/windburn/evidence/herdr/current.json)"
      herdr_status=UNKNOWN
      herdr_reason=missing_herdr_evidence
      herdr_command_present=false
      herdr_server_active=false
      herdr_socket_present=false
      herdr_socket_api_status=UNKNOWN
      herdr_process_count=0
      if [ "$herdr_present" = true ]; then
        herdr_status="$(jq -r '.status // "UNKNOWN"' /srv/windburn/evidence/herdr/current.json 2>/dev/null || printf '%s' UNKNOWN)"
        herdr_reason="$(jq -r '.reason // "unknown"' /srv/windburn/evidence/herdr/current.json 2>/dev/null || printf '%s' unknown)"
        herdr_command_present="$(jq -r '(.herdr.command_present // false) | tostring' /srv/windburn/evidence/herdr/current.json 2>/dev/null || printf '%s' false)"
        herdr_server_active="$(jq -r '(.server.service_active // false) | tostring' /srv/windburn/evidence/herdr/current.json 2>/dev/null || printf '%s' false)"
        herdr_socket_present="$(jq -r '(.server.socket_present // false) | tostring' /srv/windburn/evidence/herdr/current.json 2>/dev/null || printf '%s' false)"
        herdr_socket_api_status="$(jq -r '.server.socket_api_status // "UNKNOWN"' /srv/windburn/evidence/herdr/current.json 2>/dev/null || printf '%s' UNKNOWN)"
        herdr_process_count="$(jq -r '(.server.process_count // 0) | tostring' /srv/windburn/evidence/herdr/current.json 2>/dev/null || printf '%s' 0)"
      fi
      research_present="$(bool_file /srv/windburn/evidence/research-appliance/current.json)"
      research_status=UNKNOWN
      research_reason=missing_research_appliance_evidence
      research_staged_run_count=0
      research_public_safe=false
      research_hf_export_gated=false
      if [ "$research_present" = true ]; then
        research_status="$(jq -r '.status // "UNKNOWN"' /srv/windburn/evidence/research-appliance/current.json 2>/dev/null || printf '%s' UNKNOWN)"
        research_reason="$(jq -r '.reason // "unknown"' /srv/windburn/evidence/research-appliance/current.json 2>/dev/null || printf '%s' unknown)"
        research_staged_run_count="$(jq -r '(.staged_run_count // 0) | tostring' /srv/windburn/evidence/research-appliance/current.json 2>/dev/null || printf '%s' 0)"
        research_public_safe="$(jq -r '(.redacted_public_safe // false) | tostring' /srv/windburn/evidence/research-appliance/current.json 2>/dev/null || printf '%s' false)"
        research_hf_export_gated="$(jq -r '(.capabilities // [] | index("huggingface-export-gated") != null) | tostring' /srv/windburn/evidence/research-appliance/current.json 2>/dev/null || printf '%s' false)"
      fi

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
      elif [ "$codex_runtime_status" != PASS ]; then
        runner_status=FLAG
        runner_reason=codex_runtime_not_pass
      elif [ "$hermes_command_present" != true ]; then
        runner_status=FLAG
        runner_reason=hermes_command_missing
      elif [ "$uv_command_present" != true ]; then
        runner_status=FLAG
        runner_reason=uv_command_missing
      elif [ "$hermes_runtime_status" != PASS ]; then
        runner_status=FLAG
        runner_reason=hermes_runtime_not_pass
      elif [ "$hermes_yolo_status" != PASS ]; then
        runner_status=FLAG
        runner_reason=hermes_yolo_lane_not_pass
      elif [ "$hermes_yolo_ensured_rev_matches" != true ]; then
        runner_status=FLAG
        runner_reason=hermes_yolo_rev_not_ensured
      elif [ "$latest_smoke_verdict" != PASS ]; then
        runner_status=FLAG
        runner_reason=latest_hermes_codex_smoke_not_pass
      elif [ "$herdr_status" != PASS ]; then
        runner_status=FLAG
        runner_reason=herdr_cockpit_not_pass
      elif [ "$research_status" != PASS ]; then
        runner_status=FLAG
        runner_reason=research_appliance_not_pass
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
        --arg codex_runtime_present "$codex_runtime_present" \
        --arg codex_runtime_status "$codex_runtime_status" \
        --arg codex_runtime_reason "$codex_runtime_reason" \
        --arg codex_command_present "$codex_command_present" \
        --arg codex_version_status "$codex_version_status" \
        --arg codex_fixed_session_present "$codex_fixed_session_present" \
        --arg codex_window_present "$codex_window_present" \
        --arg codex_pane_alive "$codex_pane_alive" \
        --argjson codex_process_count "$codex_process_count" \
        --arg hermes_runtime_present "$hermes_runtime_present" \
        --arg hermes_runtime_status "$hermes_runtime_status" \
        --arg hermes_runtime_reason "$hermes_runtime_reason" \
        --arg hermes_command_present "$hermes_command_present" \
        --arg uv_command_present "$uv_command_present" \
        --arg hermes_yolo_present "$hermes_yolo_present" \
        --arg hermes_yolo_status "$hermes_yolo_status" \
        --arg hermes_yolo_reason "$hermes_yolo_reason" \
        --arg hermes_yolo_session_present "$hermes_yolo_session_present" \
        --arg hermes_yolo_window_present "$hermes_yolo_window_present" \
        --arg hermes_yolo_pane_alive "$hermes_yolo_pane_alive" \
        --argjson hermes_yolo_process_count "$hermes_yolo_process_count" \
        --arg hermes_yolo_ensured_rev_matches "$hermes_yolo_ensured_rev_matches" \
        --arg herdr_present "$herdr_present" \
        --arg herdr_status "$herdr_status" \
        --arg herdr_reason "$herdr_reason" \
        --arg herdr_command_present "$herdr_command_present" \
        --arg herdr_server_active "$herdr_server_active" \
        --arg herdr_socket_present "$herdr_socket_present" \
        --arg herdr_socket_api_status "$herdr_socket_api_status" \
        --argjson herdr_process_count "$herdr_process_count" \
        --arg research_present "$research_present" \
        --arg research_status "$research_status" \
        --arg research_reason "$research_reason" \
        --argjson research_staged_run_count "$research_staged_run_count" \
        --arg research_public_safe "$research_public_safe" \
        --arg research_hf_export_gated "$research_hf_export_gated" \
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
          codex_cli: {
            present: ($codex_runtime_present == "true"),
            status: $codex_runtime_status,
            reason: $codex_runtime_reason,
            codex_command_present: ($codex_command_present == "true"),
            version_status: $codex_version_status
          },
          codex_tui: {
            present: ($codex_runtime_present == "true"),
            status: $codex_runtime_status,
            reason: $codex_runtime_reason,
            fixed_session_present: ($codex_fixed_session_present == "true"),
            codex_window_present: ($codex_window_present == "true"),
            pane_alive: ($codex_pane_alive == "true"),
            process_count: $codex_process_count,
            command_redacted: true
          },
          hermes_runtime: {
            present: ($hermes_runtime_present == "true"),
            status: $hermes_runtime_status,
            reason: $hermes_runtime_reason,
            hermes_command_present: ($hermes_command_present == "true"),
            uv_command_present: ($uv_command_present == "true")
          },
          hermes_yolo: {
            present: ($hermes_yolo_present == "true"),
            status: $hermes_yolo_status,
            reason: $hermes_yolo_reason,
            fixed_session_present: ($hermes_yolo_session_present == "true"),
            yolo_window_present: ($hermes_yolo_window_present == "true"),
            pane_alive: ($hermes_yolo_pane_alive == "true"),
            yolo_process_count: $hermes_yolo_process_count,
            ensured_rev_matches: ($hermes_yolo_ensured_rev_matches == "true"),
            command_redacted: true
          },
          herdr_cockpit: {
            present: ($herdr_present == "true"),
            status: $herdr_status,
            reason: $herdr_reason,
            command_present: ($herdr_command_present == "true"),
            server_active: ($herdr_server_active == "true"),
            socket_present: ($herdr_socket_present == "true"),
            socket_api_status: $herdr_socket_api_status,
            process_count: $herdr_process_count,
            operator_surface: "herdr",
            attach_target_redacted: true,
            command_redacted: true
          },
          research_appliance: {
            present: ($research_present == "true"),
            status: $research_status,
            reason: $research_reason,
            staged_run_count: $research_staged_run_count,
            public_safe_evidence: ($research_public_safe == "true"),
            huggingface_export_gated: ($research_hf_export_gated == "true")
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
            "hermes-codex-smoke-readback",
            "codex-cli-command",
            "codex-fixed-tmux-lane",
            "hermes-runtime-command",
            "uv-package-manager",
            "hermes-yolo-tmux-lane",
            "herdr-cockpit-socket-api",
            "research-run-card-validation",
            "agent-memory-causality",
            "huggingface-export-gated"
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
    wants = [
      "windburn-health.service"
      "windburn-codex-runtime-status.service"
      "windburn-herdr-status.service"
      "windburn-hermes-runtime-status.service"
      "windburn-hermes-yolo-status.service"
      "windburn-research-appliance-status.service"
    ];
    after = [
      "windburn-health.service"
      "windburn-codex-runtime-status.service"
      "windburn-herdr-status.service"
      "windburn-hermes-runtime-status.service"
      "windburn-hermes-yolo-status.service"
      "windburn-research-appliance-status.service"
    ];
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
