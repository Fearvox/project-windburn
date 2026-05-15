{ config, lib, pkgs, ... }:

let
  cfg = config.services.evercoreRemote;
  composeBin = lib.getExe pkgs.docker-compose;
  healthScript = pkgs.writeShellApplication {
    name = "evercore-remote-health";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      set -euo pipefail

      evidence_dir="${cfg.evidenceDir}"
      mkdir -p "$evidence_dir"
      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT

      checked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      if curl -fsS --max-time 10 "http://${cfg.bindHost}:${toString cfg.bindPort}/health" > "$tmp"; then
        status="$(jq -r '.status // "unknown"' "$tmp" 2>/dev/null || printf 'unknown')"
        jq -n \
          --arg checked_at "$checked_at" \
          --arg status "$status" \
          --slurpfile health "$tmp" \
          '{
            schema_version: 1,
            checked_at_utc: $checked_at,
            status: $status,
            health: ($health[0] // {}),
            secret_values_recorded: false,
            redacted_public_safe: true
          }' \
          > "$evidence_dir/current.json"
        test "$status" = "healthy"
      else
        jq -n \
          --arg checked_at "$checked_at" \
          '{
            schema_version: 1,
            checked_at_utc: $checked_at,
            status: "unreachable",
            secret_values_recorded: false,
            redacted_public_safe: true
          }' \
          > "$evidence_dir/current.json"
        exit 1
      fi
    '';
  };
in
{
  options.services.evercoreRemote = {
    enable = lib.mkEnableOption "EverCore remote memory backend";

    baseDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/evercore";
      description = "Runtime directory containing compose/env files and backups.";
    };

    repoDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/evercore/repo";
      description = "EverOS checkout root used as Docker build context.";
    };

    envFile = lib.mkOption {
      type = lib.types.str;
      default = "/srv/evercore/evercore.env";
      description = "Secret-bearing EverCore env file, not committed to git.";
    };

    composeFile = lib.mkOption {
      type = lib.types.str;
      default = "/srv/evercore/docker-compose.remote.yaml";
      description = "Remote Docker Compose file.";
    };

    evidenceDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/evercore/evidence";
      description = "Directory for local health evidence.";
    };

    bindHost = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host interface for the EverCore API port.";
    };

    bindPort = lib.mkOption {
      type = lib.types.port;
      default = 1995;
      description = "Host port for EverCore API.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open bindPort in the NixOS firewall. Keep false for v0.";
    };

    allowPublicBind = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow bindHost=0.0.0.0. Requires explicit operator intent.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "evercore";
      description = "Owner for runtime directories.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "evercore";
      description = "Group for runtime directories.";
    };

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create the runtime user/group.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.allowPublicBind || cfg.bindHost != "0.0.0.0";
        message = "EverCore remote refuses bindHost=0.0.0.0 unless allowPublicBind=true.";
      }
    ];

    virtualisation.docker.enable = true;

    users.groups = lib.mkIf cfg.createUser {
      ${cfg.group} = { };
    };

    users.users = lib.mkIf cfg.createUser {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        extraGroups = [ "docker" ];
      };
    };

    environment.systemPackages = [
      pkgs.curl
      pkgs.docker-compose
      pkgs.jq
      healthScript
    ];

    environment.etc."windburn/evercore.env.example".text = ''
      # Copy to ${cfg.envFile} on the remote host with operator-owned values.
      # Do not commit the real env file.
      OPENAI_API_KEY=
      LLM_API_KEY=
      LLM_BASE_URL=
      LLM_MODEL=
      EVERCORE_MONGODB_PASSWORD=
      MINIO_ROOT_USER=
      MINIO_ROOT_PASSWORD=
    '';

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.bindPort ];

    systemd.tmpfiles.rules = [
      "d ${cfg.baseDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.evidenceDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.baseDir}/backups 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.evercore-compose = {
      description = "EverCore remote memory backend";
      wantedBy = [ "multi-user.target" ];
      after = [
        "docker.service"
        "network-online.target"
      ];
      requires = [ "docker.service" ];
      environment = {
        EVERCORE_REPO_ROOT = cfg.repoDir;
        EVERCORE_ENV_FILE = cfg.envFile;
        EVERCORE_BIND_HOST = cfg.bindHost;
        EVERCORE_BIND_PORT = toString cfg.bindPort;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = cfg.baseDir;
        ExecStartPre = [
          "${pkgs.coreutils}/bin/test -f ${cfg.composeFile}"
          "${pkgs.coreutils}/bin/test -f ${cfg.envFile}"
          "${pkgs.coreutils}/bin/test -d ${cfg.repoDir}/methods/EverCore"
        ];
        ExecStart = "${composeBin} --env-file ${cfg.envFile} -f ${cfg.composeFile} up -d --build --remove-orphans";
        ExecStop = "${composeBin} --env-file ${cfg.envFile} -f ${cfg.composeFile} down";
        TimeoutStartSec = 900;
        TimeoutStopSec = 180;
      };
    };

    systemd.services.evercore-health = {
      description = "EverCore remote health evidence";
      after = [ "evercore-compose.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${healthScript}/bin/evercore-remote-health";
      };
    };

    systemd.timers.evercore-health = {
      description = "Run EverCore remote health evidence check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
        Unit = "evercore-health.service";
      };
    };
  };
}
