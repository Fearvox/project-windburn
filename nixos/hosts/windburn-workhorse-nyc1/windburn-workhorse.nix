{ pkgs, ... }:

let
  operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEttY1KlSQZK3jMZSWHSGYWe/Or87mYX3RgnCFG9CDmX 0xvox@deMacBook-Pro.local";
in
{
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
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ operatorKey ];
  };

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

  environment.systemPackages = with pkgs; [
    curl
    fd
    gcc
    git
    gnumake
    htop
    jq
    nodejs
    openssl
    pkg-config
    python3
    ripgrep
    rsync
    tmux
    vim
    wget
  ];
}
