{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption mkEnableOption mkPackageOption types;
  cfg = config.services.agentsview;
  args =
    [
      "${cfg.package}/bin/agentsview"
      "serve"
      "--no-browser"
      "--host"
      cfg.host
      "--port"
      (toString cfg.port)
    ]
    ++ lib.optionals (cfg.publicOrigin != null) [
      "--public-origin"
      cfg.publicOrigin
    ];
in {
  options.services.agentsview = {
    enable = mkEnableOption "agentsview service";

    package = mkPackageOption pkgs.llm-agents ["agentsview"] {};

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host address for agentsview to listen on.";
    };

    port = mkOption {
      type = types.port;
      default = 3377;
      description = "Port for agentsview to listen on.";
    };

    publicOrigin = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Public origin URL agentsview advertises for browser access.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [cfg.package];

    systemd.user.services.agentsview = {
      Unit = {
        Description = "agentsview service";
      };

      Service = {
        ExecStart = lib.escapeShellArgs args;
        Restart = "always";
      };

      Install = {
        WantedBy = ["default.target"];
      };
    };
  };
}
