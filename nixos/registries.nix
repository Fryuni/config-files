{ inputs, ... }:
let
  base = "/etc/nixpkgs/channels";
  nixpkgsPath = "${base}/nixpkgs";
  nixpkgsStablePath = "${base}/nixpkgsStable";
  devshellPath = "${base}/devshell";
in
{
  nix.nixPath = [
    "nixpkgs=${nixpkgsPath}"
    "nixpkgs-stable=${nixpkgsStablePath}"
    "devshell=${devshellPath}"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  system.activationScripts.snabblab = ''
    /run/current-system/sw/bin/nix-channel --update
  '';
  systemd.tmpfiles.rules = [
    "L+ ${nixpkgsPath}       - - - - ${inputs.nixpkgs}"
    "L+ ${nixpkgsStablePath} - - - - ${inputs.nixpkgs-stable}"
    "L+ ${devshellPath}      - - - - ${inputs.devshell}"
  ];

  nix.registry = {
    nixpkgs.flake = inputs.nixpkgs;
    nixpkgs-stable.flake = inputs.nixpkgs-stable;
    nixpkgs-master.flake = inputs.nixpkgs-master;
    home-manager.flake = inputs.home-manager;
    flake-utils.flake = inputs.flake-utils;
    devshell.flake = inputs.devshell;

    # node.to = {
    #   type = "github";
    #   owner = "andyrichardson";
    #   repo = "nix-node";
    # };
  };
}
