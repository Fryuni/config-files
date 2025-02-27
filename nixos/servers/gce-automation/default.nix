{...}: {
  imports = [
    ../common-gce.nix
  ];

  environment.systemPackages = with pkgs; [
    twitch-dl
    twitch-cli
  ];
}
