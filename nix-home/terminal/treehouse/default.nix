{
  lib,
  pkgs,
  config,
  ...
}: {
  config = lib.mkIf (pkgs.stdenv.buildPlatform.system == pkgs.stdenv.hostPlatform.system) {
    home.packages = with pkgs; [
      treehouse
      bun
    ];

    xdg.configFile = {
      "treehouse/config.toml".source = (pkgs.formats.toml {}).generate "treehouse-config.toml" {
        hooks = {
          post_create = ["${config.xdg.configHome}/treehouse/hooks/post-create.ts"];
          pre_destroy = ["${config.xdg.configHome}/treehouse/hooks/pre-destroy.ts"];
        };
      };

      "treehouse/hooks/post-create.ts" = {
        source = ./post-create.ts;
        executable = true;
      };

      "treehouse/hooks/pre-destroy.ts" = {
        source = ./pre-destroy.ts;
        executable = true;
      };
    };
  };
}
