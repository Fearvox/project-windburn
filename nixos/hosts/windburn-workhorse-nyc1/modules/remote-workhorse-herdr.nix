{ pkgs, ... }:

let
  herdrVersion = "0.5.5";
  herdrAsset =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then "herdr-linux-x86_64"
    else throw "Herdr cockpit is pinned only for x86_64-linux workhorse hosts";

  herdrPackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr";
    version = herdrVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/ogulcancelik/herdr/releases/download/v${herdrVersion}/${herdrAsset}";
      hash = "sha256-DaVGmZv6hAnZzgXmc/BZHExvfWB5OCJ3d05p+aH5LQI=";
    };
    dontUnpack = true;
    installPhase = ''
      install -D -m 0755 "$src" "$out/bin/herdr"
    '';
  };

  herdrConfig = pkgs.writeText "windburn-herdr-config.toml" ''
    [theme]
    name = "kanagawa"

    [ui]
    accent = "green"
    confirm_close = true

    [ui.toast]
    delivery = "off"

    [ui.sound]
    enabled = false

    [advanced]
    scrollback_limit_bytes = 10000000
  '';

  windburnHerdrStatus = pkgs.writeShellApplication {
    name = "windburn-herdr-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.procps
      pkgs.systemd
      herdrPackage
    ];
    text = ''
      set -eu

      out_dir=/srv/windburn/evidence/herdr
      mkdir -p "$out_dir"

      generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      hostname="$(cat /proc/sys/kernel/hostname)"
      herdr_bin="$(command -v herdr || true)"
      herdr_present=false
      if [ -n "$herdr_bin" ] && [ -x "$herdr_bin" ]; then
        herdr_present=true
      fi

      version_status=SKIPPED
      version_head=""
      version_exit_code=-1
      if [ "$herdr_present" = true ]; then
        version_file="$out_dir/version.$$.tmp"
        if timeout 30 "$herdr_bin" --version >"$version_file" 2>&1; then
          version_status=PASS
          version_exit_code=0
        else
          version_exit_code=$?
          version_status=FLAG
        fi
        version_head="$(sed -n '1,3p' "$version_file")"
        rm -f "$version_file"
      fi

      server_service_active=false
      if systemctl is-active --quiet windburn-herdr-server.service; then
        server_service_active=true
      fi

      socket_present=false
      if [ -S /root/.config/herdr/herdr.sock ]; then
        socket_present=true
      fi

      socket_api_status=SKIPPED
      socket_api_exit_code=-1
      if [ "$herdr_present" = true ]; then
        status_file="$out_dir/status.$$.tmp"
        if HOME=/root HERDR_CONFIG_PATH=/root/.config/herdr/config.toml timeout 30 "$herdr_bin" status >"$status_file" 2>&1; then
          if grep -Eq 'status: running' "$status_file"; then
            socket_api_status=PASS
            socket_api_exit_code=0
          else
            socket_api_status=FLAG
            socket_api_exit_code=0
          fi
        else
          socket_api_exit_code=$?
          socket_api_status=FLAG
        fi
        rm -f "$status_file"
      fi

      process_count="$(pgrep -f 'herdr server' 2>/dev/null | wc -l | tr -d ' ')"

      status=PASS
      reason=herdr_cockpit_ready
      if [ "$herdr_present" != true ]; then
        status=FLAG
        reason=herdr_command_missing
      elif [ "$version_status" != PASS ]; then
        status=FLAG
        reason=herdr_version_probe_failed
      elif [ "$server_service_active" != true ]; then
        status=FLAG
        reason=herdr_server_service_inactive
      elif [ "$socket_present" != true ]; then
        status=FLAG
        reason=herdr_socket_missing
      elif [ "$socket_api_status" != PASS ]; then
        status=FLAG
        reason=herdr_socket_api_not_ready
      fi

      tmp="$out_dir/current.json.tmp"
      jq -n \
        --arg generated_at "$generated_at" \
        --arg hostname "$hostname" \
        --arg status "$status" \
        --arg reason "$reason" \
        --arg herdr_present "$herdr_present" \
        --arg version_status "$version_status" \
        --argjson version_exit_code "$version_exit_code" \
        --arg version_head "$version_head" \
        --arg server_service_active "$server_service_active" \
        --arg socket_present "$socket_present" \
        --arg socket_api_status "$socket_api_status" \
        --argjson socket_api_exit_code "$socket_api_exit_code" \
        --argjson process_count "$process_count" \
        '{
          schema_version: 1,
          generated_at_utc: $generated_at,
          runner_id: "windburn-herdr-cockpit-v0",
          hostname: $hostname,
          status: $status,
          reason: $reason,
          herdr: {
            version: "'"${herdrVersion}"'",
            command_present: ($herdr_present == "true"),
            version_probe: {
              status: $version_status,
              exit_code: $version_exit_code,
              head: $version_head
            }
          },
          server: {
            service: "windburn-herdr-server",
            service_active: ($server_service_active == "true"),
            socket_present: ($socket_present == "true"),
            socket_api_status: $socket_api_status,
            socket_api_exit_code: $socket_api_exit_code,
            process_count: $process_count
          },
          operator_surface: {
            kind: "herdr",
            cockpit: true,
            socket_api: ($socket_api_status == "PASS"),
            attach_target_redacted: true,
            command_redacted: true
          },
          remote_mutation: false,
          secret_values_recorded: false,
          redacted_public_safe: true
        }' > "$tmp"

      mv "$tmp" "$out_dir/current.json"
      chown -R windburn:windburn /srv/windburn/evidence
      chmod 0755 /srv/windburn/evidence /srv/windburn/evidence/herdr
      chmod 0644 "$out_dir/current.json"
      cat "$out_dir/current.json"
    '';
  };
in
{
  environment.systemPackages = [
    herdrPackage
    windburnHerdrStatus
  ];

  systemd.tmpfiles.rules = [
    "d /root/.config/herdr 0700 root root -"
    "d /srv/windburn/evidence/herdr 0755 windburn windburn -"
  ];

  systemd.services.windburn-herdr-server = {
    description = "Run Windburn Herdr cockpit socket server";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
    ];
    after = [
      "network-online.target"
    ];
    path = [
      herdrPackage
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "simple";
      User = "root";
      Group = "root";
      WorkingDirectory = "/srv/windburn";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "HOME=/root"
        "HERDR_CONFIG_PATH=/root/.config/herdr/config.toml"
      ];
      NoNewPrivileges = true;
      PrivateTmp = false;
    };
    preStart = ''
      install -d -m 0700 /root/.config/herdr
      install -m 0600 ${herdrConfig} /root/.config/herdr/config.toml
    '';
    script = ''
      exec ${herdrPackage}/bin/herdr server
    '';
  };

  systemd.services.windburn-herdr-status = {
    description = "Write Windburn Herdr cockpit evidence";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "windburn-herdr-server.service"
    ];
    after = [
      "windburn-herdr-server.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      PrivateTmp = false;
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/srv/windburn/evidence"
      ];
    };
    script = ''
      exec ${windburnHerdrStatus}/bin/windburn-herdr-status
    '';
  };

  systemd.timers.windburn-herdr-status = {
    description = "Refresh Windburn Herdr cockpit evidence";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "120s";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Unit = "windburn-herdr-status.service";
    };
  };
}
