{ pkgs, ... }:

let
  windburnHealth = pkgs.writeShellApplication {
    name = "windburn-health";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnused
      pkgs.jq
      pkgs.procps
      pkgs.systemd
    ];
    text = ''
      set -eu

      out_dir=/srv/windburn/evidence/health
      mkdir -p "$out_dir"

      generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      hostname="$(cat /proc/sys/kernel/hostname)"
      os_pretty="$(
        # shellcheck disable=SC1091
        . /etc/os-release
        printf '%s' "$PRETTY_NAME"
      )"
      kernel="$(uname -srmo)"
      system_state="$(systemctl is-system-running || true)"
      failed_units="$(systemctl --failed --no-legend --plain | sed '/^$/d' | wc -l | tr -d ' ')"
      status=FLAG
      reason=system_not_fully_running
      if [ "$system_state" = running ] && [ "$failed_units" = 0 ]; then
        status=PASS
        reason=remote_health_ready
      elif [ "$failed_units" != 0 ]; then
        reason=failed_units_present
      fi
      disk_root="$(df -h / | awk 'NR == 2 {print $0}')"
      mem_line="$(free -h | awk '/^Mem:/ {print $0}')"
      swap_line="$(free -h | awk '/^Swap:/ {print $0}')"

      tmp="$out_dir/current.json.tmp"
      jq -n \
        --arg generated_at "$generated_at" \
        --arg status "$status" \
        --arg reason "$reason" \
        --arg hostname "$hostname" \
        --arg os "$os_pretty" \
        --arg kernel "$kernel" \
        --arg system_state "$system_state" \
        --arg failed_units "$failed_units" \
        --arg disk_root "$disk_root" \
        --arg memory "$mem_line" \
        --arg swap "$swap_line" \
        '{
          schema_version: 1,
          generated_at_utc: $generated_at,
          status: $status,
          reason: $reason,
          summary: "sanitized remote workhorse health snapshot",
          hostname: $hostname,
          os: $os,
          kernel: $kernel,
          system_state: $system_state,
          failed_units: ($failed_units | tonumber),
          disk_root: $disk_root,
          memory: $memory,
          swap: $swap,
          secret_values_recorded: false,
          redacted_public_safe: true
        }' > "$tmp"

      mv "$tmp" "$out_dir/current.json"
      chown -R windburn:windburn /srv/windburn/evidence
      chmod 0755 /srv/windburn/evidence /srv/windburn/evidence/health
      chmod 0644 "$out_dir/current.json"
      cat "$out_dir/current.json"
    '';
  };
in
{
  environment.systemPackages = [
    windburnHealth
  ];

  environment.etc."windburn/secrets.env.example".text = ''
    # Copy to an operator-owned secret store, never into git.
    # The current foundation layer only creates paths and proof surfaces.
    OPENAI_API_KEY=
    DIGITALOCEAN_ACCESS_TOKEN=
    HERMES_PROVIDER_BASE_URL=
  '';

  systemd.tmpfiles.rules = [
    "d /srv/windburn 0755 windburn windburn -"
    "d /srv/windburn/bin 0755 windburn windburn -"
    "d /srv/windburn/cache 0755 windburn windburn -"
    "d /srv/windburn/evidence 0755 windburn windburn -"
    "d /srv/windburn/evidence/health 0755 windburn windburn -"
    "d /srv/windburn/runs 0755 windburn windburn -"
    "d /srv/windburn/state 0755 windburn windburn -"
    "d /srv/windburn/tmp 0755 windburn windburn -"
    "d /srv/windburn/worktrees 0755 windburn windburn -"
    "d /srv/windburn/secrets 0700 root root -"
  ];

  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1G
    MaxRetentionSec=14day
  '';

  systemd.services.windburn-health = {
    description = "Write Windburn remote workhorse health evidence";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/srv/windburn/evidence"
      ];
    };
    script = ''
      exec ${windburnHealth}/bin/windburn-health
    '';
  };

  systemd.timers.windburn-health = {
    description = "Refresh Windburn remote workhorse health evidence";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Unit = "windburn-health.service";
    };
  };
}
