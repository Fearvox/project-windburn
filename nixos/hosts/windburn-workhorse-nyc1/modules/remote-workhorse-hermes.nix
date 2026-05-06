{ pkgs, ... }:

let
  hermesRev = "6f2dab248a6cc8591af46e5deb2dc939c2b43146";
  hermesFlake = builtins.getFlake "github:NousResearch/hermes-agent/${hermesRev}";
  hermesAgent = hermesFlake.packages.${pkgs.system}.default;

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
  ];

  environment.variables = {
    WINDBURN_HERMES_GITHUB_REV = hermesRev;
  };

  systemd.tmpfiles.rules = [
    "d /srv/windburn/evidence/hermes-runtime 0755 windburn windburn -"
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
}
