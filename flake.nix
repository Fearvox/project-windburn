{
  description = "Windburn Remote Workhorse control plane";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crane.url = "github:ipetkov/crane";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
      crane,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };
        toolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "clippy"
            "rustfmt"
          ];
        };
        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
        commonArgs = {
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
      in
      {
        packages.runtimectl = craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });
        packages.default = self.packages.${system}.runtimectl;

        checks.runtimectl = self.packages.${system}.runtimectl;

        devShells.default = pkgs.mkShell {
          packages = [
            toolchain
            pkgs.just
            pkgs.cargo-nextest
            pkgs.cargo-deny
            pkgs.cargo-audit
            pkgs.nix-output-monitor
            pkgs.nvd
            pkgs.sops
            pkgs.doctl
          ];
        };
      }
    );
}

