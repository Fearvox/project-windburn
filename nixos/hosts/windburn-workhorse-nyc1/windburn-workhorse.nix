{ pkgs, ... }:

let
  operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEttY1KlSQZK3jMZSWHSGYWe/Or87mYX3RgnCFG9CDmX 0xvox@deMacBook-Pro.local";
in
{
  imports = [
    ./modules/remote-workhorse-foundation.nix
    ./modules/remote-workhorse-codex.nix
    ./modules/remote-workhorse-evercore.nix
    ./modules/remote-workhorse-herdr.nix
    ./modules/remote-workhorse-hermes.nix
    ./modules/remote-workhorse-research.nix
    ./modules/remote-workhorse-runner.nix
  ];

  # nixos-infect owns boot, hardware, network, hostname, and stateVersion
  # during first boot. This import only adds operator/runtime policy.
  time.timeZone = "UTC";

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      auto-optimise-store = true;
      max-jobs = "auto";
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [ operatorKey ];

  users.users.windburn = {
    isNormalUser = true;
    group = "windburn";
    extraGroups = [
      "wheel"
      "systemd-journal"
    ];
    openssh.authorizedKeys.keys = [ operatorKey ];
  };

  users.groups.windburn = { };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  services.evercoreRemote = {
    enable = true;
    baseDir = "/srv/evercore";
    repoDir = "/srv/evercore/repo";
    envFile = "/srv/evercore/evercore.env";
    composeFile = "/srv/evercore/docker-compose.remote.yaml";
    evidenceDir = "/srv/evercore/evidence";
    bindHost = "127.0.0.1";
    bindPort = 1995;
    openFirewall = false;
    allowPublicBind = false;
  };

  environment.systemPackages = with pkgs; [
    age
    btop
    curl
    fd
    gcc
    gh
    git
    gnumake
    htop
    iotop
    jq
    just
    lsof
    nodejs
    nix-output-monitor
    nvd
    openssl
    pkg-config
    python3
    ripgrep
    rsync
    sops
    strace
    tmux
    vim
    wget
  ];
}
