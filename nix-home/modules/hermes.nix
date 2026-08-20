{
  config,
  lib,
  pkgs,
  ...
}: {
  options.hermes.enabled = lib.mkEnableOption "Hermes agent";

  config = lib.mkIf config.hermes.enabled {
    programs.git.enable = true;

    home.packages = with pkgs; [
      uv
      ffmpeg
      ripgrep
    ];

    services.git-sync = {
      enable = true;
      repositories.hermes = {
        path = "${config.home.homeDirectory}/.hermes";
        uri = "git@git-ss.rudd-agama.ts.net:configs/hermes.git";
      };
    };
  };
}
