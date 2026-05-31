{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../nixos/modules/honcho.nix
  ];

  age.secrets.honcho-openai-key = {
    rekeyFile = ../../secrets/ai/openai;
    owner = "honcho";
    group = "honcho";
  };

  services.honcho = {
    enable = true;
    package = pkgs.lib.makeAuthWrapper pkgs.honcho {
      LLM_OPENAI_API_KEY = {
        file = config.age.secrets.honcho-openai-key.path;
      };
    };
  };

  services.lferrazTailnetAccess.proxy.aliases.honcho = config.services.honcho.port;
}
