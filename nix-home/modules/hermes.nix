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

    services.machineBackups.directories = [
      {
        name = "hermes";
        kind = "sqlite";
        paths = [config.services.git-sync.repositories.hermes.path];
        scopes = ["home" "services"];
        units = [
          {
            name = "git-sync-hermes.service";
            type = "user";
          }
        ];
        pauseOpenWriters = true;
        writerCoverageNote = "SQLite DBs are captured consistently. Git-sync and detected processes holding files open under this directory are paused. Processes that open and close files between writes may evade discovery; verify associated files during rehearsal.";
      }
    ];
  };
}
