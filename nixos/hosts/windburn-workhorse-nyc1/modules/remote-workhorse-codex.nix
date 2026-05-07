{ pkgs, ... }:

let
  codexNixpkgsRev = "ed67bc86e84e51d4a88e73c7fd36006dc876476f";
  codexNixpkgs = builtins.getFlake "github:NixOS/nixpkgs/${codexNixpkgsRev}";
  codexPackage = codexNixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.codex;
  codexSession = "windburn-codex-runtime";
  codexWindow = "codex-yolo";
  codexWorkdir = "/srv/windburn";
  codexModel = "gpt-5.5";

  windburnCodexRuntimeStatus = pkgs.writeShellApplication {
    name = "windburn-codex-runtime-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.procps
      pkgs.tmux
      codexPackage
    ];
    text = ''
      set -eu

      out_dir=/srv/windburn/evidence/codex-runtime
      mkdir -p "$out_dir"

      generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      hostname="$(cat /proc/sys/kernel/hostname)"
      session="${codexSession}"
      window="${codexWindow}"
      codex_bin="$(command -v codex || true)"
      codex_present=false
      if [ -n "$codex_bin" ] && [ -x "$codex_bin" ]; then
        codex_present=true
      fi

      version_status=SKIPPED
      version_head=""
      version_exit_code=-1
      if [ "$codex_present" = true ]; then
        version_file="$out_dir/version.$$.tmp"
        if timeout 90 "$codex_bin" --version >"$version_file" 2>&1; then
          version_status=PASS
          version_exit_code=0
        else
          version_exit_code=$?
          version_status=FLAG
        fi
        version_head="$(sed -n '1,8p' "$version_file")"
        rm -f "$version_file"
      fi

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

      process_count="$(pgrep -fc '(/run/current-system/sw/bin/codex|codex .*--no-alt-screen)' 2>/dev/null || printf '%s' 0)"

      status=PASS
      reason=codex_runtime_ready
      if [ "$codex_present" != true ]; then
        status=FLAG
        reason=codex_command_missing
      elif [ "$version_status" != PASS ]; then
        status=FLAG
        reason=codex_version_probe_failed
      elif [ "$tmux_present" != true ]; then
        status=FLAG
        reason=tmux_missing
      elif [ "$session_present" != true ]; then
        status=FLAG
        reason=codex_session_missing
      elif [ "$window_present" != true ]; then
        status=FLAG
        reason=codex_window_missing
      elif [ "$pane_alive" != true ]; then
        status=FLAG
        reason=codex_pane_dead
      elif [ "$process_count" -lt 1 ]; then
        status=FLAG
        reason=codex_process_missing
      fi

      tmp="$out_dir/current.json.tmp"
      jq -n \
        --arg generated_at "$generated_at" \
        --arg hostname "$hostname" \
        --arg status "$status" \
        --arg reason "$reason" \
        --arg codex_bin "$codex_bin" \
        --arg codex_present "$codex_present" \
        --arg version_status "$version_status" \
        --argjson version_exit_code "$version_exit_code" \
        --arg version_head "$version_head" \
        --arg tmux_present "$tmux_present" \
        --arg tmux_version "$tmux_version" \
        --arg session_present "$session_present" \
        --arg window_present "$window_present" \
        --arg pane_alive "$pane_alive" \
        --argjson process_count "$process_count" \
        '{
          schema_version: 1,
          generated_at_utc: $generated_at,
          runner_id: "windburn-codex-runtime-v0",
          hostname: $hostname,
          status: $status,
          reason: $reason,
          codex: {
            package: "nixpkgs#codex",
            nixpkgs_rev: "'"${codexNixpkgsRev}"'",
            model: "'"${codexModel}"'",
            command_present: ($codex_present == "true"),
            bin: (if ($codex_bin | length) == 0 then null else $codex_bin end),
            version_probe: {
              status: $version_status,
              exit_code: $version_exit_code,
              head: $version_head
            },
            command_redacted: true
          },
          tmux: {
            present: ($tmux_present == "true"),
            version: (if ($tmux_version | length) == 0 then null else $tmux_version end)
          },
          lane: {
            fixed_session_present: ($session_present == "true"),
            codex_window_present: ($window_present == "true"),
            pane_alive: ($pane_alive == "true"),
            process_count: $process_count,
            command_kind: "codex-yolo",
            command_redacted: true
          },
          remote_mutation: false,
          secret_values_recorded: false,
          redacted_public_safe: true
        }' > "$tmp"

      mv "$tmp" "$out_dir/current.json"
      chown -R windburn:windburn /srv/windburn/evidence
      chmod 0755 /srv/windburn/evidence /srv/windburn/evidence/codex-runtime
      chmod 0644 "$out_dir/current.json"
      cat "$out_dir/current.json"
    '';
  };

  windburnCodexYoloEnsure = pkgs.writeShellApplication {
    name = "windburn-codex-yolo-ensure";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.procps
      pkgs.tmux
      codexPackage
      windburnCodexRuntimeStatus
    ];
    text = ''
      set -eu

      session="${codexSession}"
      window="${codexWindow}"
      workdir="${codexWorkdir}"
      command="cd $workdir && export HOME=/root CODEX_HOME=/root/.codex; exec /run/current-system/sw/bin/codex --no-alt-screen --model ${codexModel} --sandbox danger-full-access --ask-for-approval never -C $workdir"

      mkdir -p "$workdir"

      window_exists() {
        tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null | grep -Fxq "$window"
      }

      pane_dead() {
        tmux display-message -p -t "$session:$window" '#{pane_dead}' 2>/dev/null || printf '%s' 1
      }

      codex_process_count() {
        pgrep -fc '(/run/current-system/sw/bin/codex|codex .*--no-alt-screen)' 2>/dev/null || printf '%s' 0
      }

      if ! tmux has-session -t "$session" 2>/dev/null; then
        tmux new-session -d -s "$session" -n shell -c "$workdir"
      fi

      if window_exists; then
        if [ "$(pane_dead)" != 0 ] || [ "$(codex_process_count)" -lt 1 ]; then
          tmux respawn-pane -k -t "$session:$window" "$command"
        fi
      else
        tmux new-window -t "$session" -n "$window" "$command"
      fi

      sleep 4
      exec windburn-codex-runtime-status
    '';
  };
in
{
  environment.systemPackages = [
    codexPackage
    windburnCodexRuntimeStatus
    windburnCodexYoloEnsure
  ];

  systemd.tmpfiles.rules = [
    "d /srv/windburn/evidence/codex-runtime 0755 windburn windburn -"
  ];

  systemd.services.windburn-codex-yolo-ensure = {
    description = "Ensure Windburn Codex yolo tmux lane";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
    ];
    after = [
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      PrivateTmp = false;
    };
    script = ''
      exec ${windburnCodexYoloEnsure}/bin/windburn-codex-yolo-ensure
    '';
  };

  systemd.timers.windburn-codex-yolo-ensure = {
    description = "Repair Windburn Codex yolo tmux lane";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "165s";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Unit = "windburn-codex-yolo-ensure.service";
    };
  };

  systemd.services.windburn-codex-runtime-status = {
    description = "Write Windburn Codex runtime evidence";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "windburn-codex-yolo-ensure.service"
    ];
    after = [
      "windburn-codex-yolo-ensure.service"
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
      exec ${windburnCodexRuntimeStatus}/bin/windburn-codex-runtime-status
    '';
  };

  systemd.timers.windburn-codex-runtime-status = {
    description = "Refresh Windburn Codex runtime evidence";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "225s";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Unit = "windburn-codex-runtime-status.service";
    };
  };
}
