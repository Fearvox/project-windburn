{ pkgs, ... }:

let
  hermesRev = "6f2dab248a6cc8591af46e5deb2dc939c2b43146";
  hermesFlake = builtins.getFlake "github:NousResearch/hermes-agent/${hermesRev}";
  hermesAgent = hermesFlake.packages.${pkgs.system}.default;
  yoloSession = "windburn-hermes-runtime";
  yoloWindow = "hermes-yolo";
  yoloWorkdir = "/srv/windburn";

  windburnHermesYoloStatus = pkgs.writeShellApplication {
    name = "windburn-hermes-yolo-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.procps
      pkgs.tmux
    ];
    text = ''
      set -eu

      out_dir=/srv/windburn/evidence/hermes-yolo
      mkdir -p "$out_dir"

      generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      hostname="$(cat /proc/sys/kernel/hostname)"
      session="${yoloSession}"
      window="${yoloWindow}"
      tmux_present=false
      tmux_version=""
      session_present=false
      window_present=false
      pane_alive=false
      process_count=0

      if command -v tmux >/dev/null 2>&1; then
        tmux_present=true
        tmux_version="$(tmux -V 2>/dev/null || true)"
        if tmux has-session -t "$session" 2>/dev/null; then
          session_present=true
          if tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null | grep -Fxq "$window"; then
            window_present=true
            pane_dead="$(tmux display-message -p -t "$session:$window" '#{pane_dead}' 2>/dev/null || printf '%s' 1)"
            if [ "$pane_dead" = 0 ]; then
              pane_alive=true
            fi
          fi
        fi
      fi

      process_count="$(pgrep -fc '(hermes .*--yolo|python3 .*hermes .*--yolo|/run/current-system/sw/bin/hermes --yolo)' 2>/dev/null || printf '%s' 0)"

      status=PASS
      reason=hermes_yolo_lane_ready
      if [ "$tmux_present" != true ]; then
        status=FLAG
        reason=tmux_missing
      elif [ "$session_present" != true ]; then
        status=FLAG
        reason=hermes_yolo_session_missing
      elif [ "$window_present" != true ]; then
        status=FLAG
        reason=hermes_yolo_window_missing
      elif [ "$pane_alive" != true ]; then
        status=FLAG
        reason=hermes_yolo_pane_dead
      elif [ "$process_count" -lt 1 ]; then
        status=FLAG
        reason=hermes_yolo_process_missing
      fi

      tmp="$out_dir/current.json.tmp"
      jq -n \
        --arg generated_at "$generated_at" \
        --arg hostname "$hostname" \
        --arg status "$status" \
        --arg reason "$reason" \
        --arg tmux_present "$tmux_present" \
        --arg tmux_version "$tmux_version" \
        --arg session_present "$session_present" \
        --arg window_present "$window_present" \
        --arg pane_alive "$pane_alive" \
        --argjson process_count "$process_count" \
        '{
          schema_version: 1,
          generated_at_utc: $generated_at,
          runner_id: "windburn-hermes-yolo-lane-v0",
          hostname: $hostname,
          status: $status,
          reason: $reason,
          tmux: {
            present: ($tmux_present == "true"),
            version: (if ($tmux_version | length) == 0 then null else $tmux_version end)
          },
          lane: {
            fixed_session_present: ($session_present == "true"),
            yolo_window_present: ($window_present == "true"),
            pane_alive: ($pane_alive == "true"),
            yolo_process_count: $process_count,
            command_kind: "hermes-yolo",
            command_redacted: true
          },
          remote_mutation: false,
          secret_values_recorded: false,
          redacted_public_safe: true
        }' > "$tmp"

      mv "$tmp" "$out_dir/current.json"
      chown -R windburn:windburn /srv/windburn/evidence
      chmod 0755 /srv/windburn/evidence /srv/windburn/evidence/hermes-yolo
      chmod 0644 "$out_dir/current.json"
      cat "$out_dir/current.json"
    '';
  };

  windburnHermesYoloEnsure = pkgs.writeShellApplication {
    name = "windburn-hermes-yolo-ensure";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.procps
      pkgs.tmux
      hermesAgent
      windburnHermesYoloStatus
    ];
    text = ''
      set -eu

      session="${yoloSession}"
      window="${yoloWindow}"
      workdir="${yoloWorkdir}"
      command="cd $workdir && exec /run/current-system/sw/bin/hermes --yolo"

      mkdir -p "$workdir"

      window_exists() {
        tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null | grep -Fxq "$window"
      }

      pane_dead() {
        tmux display-message -p -t "$session:$window" '#{pane_dead}' 2>/dev/null || printf '%s' 1
      }

      yolo_process_count() {
        pgrep -fc '(hermes .*--yolo|python3 .*hermes .*--yolo|/run/current-system/sw/bin/hermes --yolo)' 2>/dev/null || printf '%s' 0
      }

      if ! tmux has-session -t "$session" 2>/dev/null; then
        tmux new-session -d -s "$session" -n shell -c "$workdir"
      fi

      if window_exists; then
        if [ "$(pane_dead)" != 0 ] || [ "$(yolo_process_count)" -lt 1 ]; then
          tmux respawn-pane -k -t "$session:$window" "$command"
        fi
      else
        tmux new-window -t "$session" -n "$window" "$command"
      fi

      sleep 4
      exec windburn-hermes-yolo-status
    '';
  };

  windburnHermesRuntimeStatus = pkgs.writeShellApplication {
    name = "windburn-hermes-runtime-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.gnused
      hermesAgent
      pkgs.uv
    ];
    text = ''
      set -eu

      out_dir=/srv/windburn/evidence/hermes-runtime
      mkdir -p "$out_dir"

      generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      hostname="$(cat /proc/sys/kernel/hostname)"
      hermes_bin="$(command -v hermes || true)"
      uv_bin="$(command -v uv || true)"
      hermes_rev="${hermesRev}"
      hermes_package="${hermesAgent}"

      hermes_present=false
      if [ -n "$hermes_bin" ] && [ -x "$hermes_bin" ]; then
        hermes_present=true
      fi

      uv_present=false
      if [ -n "$uv_bin" ] && [ -x "$uv_bin" ]; then
        uv_present=true
      fi

      version_status=SKIPPED
      version_head=""
      version_exit_code=-1
      if [ "$hermes_present" = true ]; then
        version_file="$out_dir/version.$$.tmp"
        if timeout 90 "$hermes_bin" --version >"$version_file" 2>&1; then
          version_status=PASS
          version_exit_code=0
        else
          version_exit_code=$?
          version_status=FLAG
        fi
        version_head="$(sed -n '1,8p' "$version_file")"
        rm -f "$version_file"
      fi

      status=PASS
      reason=hermes_runtime_ready
      if [ "$hermes_present" != true ]; then
        status=FLAG
        reason=hermes_command_missing
      elif [ "$uv_present" != true ]; then
        status=FLAG
        reason=uv_command_missing
      elif [ "$version_status" != PASS ]; then
        status=FLAG
        reason=hermes_version_probe_failed
      fi

      tmp="$out_dir/current.json.tmp"
      jq -n \
        --arg generated_at "$generated_at" \
        --arg hostname "$hostname" \
        --arg status "$status" \
        --arg reason "$reason" \
        --arg hermes_rev "$hermes_rev" \
        --arg hermes_package "$hermes_package" \
        --arg hermes_bin "$hermes_bin" \
        --arg uv_bin "$uv_bin" \
        --arg hermes_present "$hermes_present" \
        --arg uv_present "$uv_present" \
        --arg version_status "$version_status" \
        --argjson version_exit_code "$version_exit_code" \
        --arg version_head "$version_head" \
        '{
          schema_version: 1,
          generated_at_utc: $generated_at,
          runner_id: "windburn-hermes-runtime-v0",
          hostname: $hostname,
          status: $status,
          reason: $reason,
          hermes: {
            source: "github:NousResearch/hermes-agent",
            rev: $hermes_rev,
            package: $hermes_package,
            command_present: ($hermes_present == "true"),
            bin: (if ($hermes_bin | length) == 0 then null else $hermes_bin end),
            version_probe: {
              status: $version_status,
              exit_code: $version_exit_code,
              head: $version_head
            }
          },
          uv: {
            command_present: ($uv_present == "true"),
            bin: (if ($uv_bin | length) == 0 then null else $uv_bin end)
          },
          remote_mutation: false,
          secret_values_recorded: false,
          redacted_public_safe: true
        }' > "$tmp"

      mv "$tmp" "$out_dir/current.json"
      chown -R windburn:windburn /srv/windburn/evidence
      chmod 0755 /srv/windburn/evidence /srv/windburn/evidence/hermes-runtime
      chmod 0644 "$out_dir/current.json"
      cat "$out_dir/current.json"
    '';
  };
in
{
  environment.systemPackages = [
    hermesAgent
    pkgs.uv
    windburnHermesRuntimeStatus
    windburnHermesYoloEnsure
    windburnHermesYoloStatus
  ];

  environment.variables = {
    WINDBURN_HERMES_GITHUB_REV = hermesRev;
  };

  systemd.tmpfiles.rules = [
    "d /srv/windburn/evidence/hermes-runtime 0755 windburn windburn -"
    "d /srv/windburn/evidence/hermes-yolo 0755 windburn windburn -"
  ];

  systemd.services.windburn-hermes-runtime-status = {
    description = "Write Windburn Hermes runtime evidence";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      PrivateTmp = false;
      ProtectHome = "read-only";
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/srv/windburn/evidence"
      ];
    };
    script = ''
      exec ${windburnHermesRuntimeStatus}/bin/windburn-hermes-runtime-status
    '';
  };

  systemd.timers.windburn-hermes-runtime-status = {
    description = "Refresh Windburn Hermes runtime evidence";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "120s";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Unit = "windburn-hermes-runtime-status.service";
    };
  };

  systemd.services.windburn-hermes-yolo-ensure = {
    description = "Ensure Windburn Hermes yolo tmux lane";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "windburn-hermes-runtime-status.service"
    ];
    after = [
      "network-online.target"
      "windburn-hermes-runtime-status.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      PrivateTmp = false;
    };
    script = ''
      exec ${windburnHermesYoloEnsure}/bin/windburn-hermes-yolo-ensure
    '';
  };

  systemd.timers.windburn-hermes-yolo-ensure = {
    description = "Repair Windburn Hermes yolo tmux lane";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "150s";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Unit = "windburn-hermes-yolo-ensure.service";
    };
  };

  systemd.services.windburn-hermes-yolo-status = {
    description = "Write Windburn Hermes yolo tmux lane evidence";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "windburn-hermes-yolo-ensure.service"
    ];
    after = [
      "windburn-hermes-yolo-ensure.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      PrivateTmp = false;
      ProtectHome = "read-only";
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/srv/windburn/evidence"
      ];
    };
    script = ''
      exec ${windburnHermesYoloStatus}/bin/windburn-hermes-yolo-status
    '';
  };

  systemd.timers.windburn-hermes-yolo-status = {
    description = "Refresh Windburn Hermes yolo tmux lane evidence";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "210s";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Unit = "windburn-hermes-yolo-status.service";
    };
  };
}
