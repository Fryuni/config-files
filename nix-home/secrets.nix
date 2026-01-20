{config, ...}: {
  age.secrets = {
    github-key.file = ../secrets/github-key;
    habitica-key.file = ../secrets/habitica-key;
    openai-key.file = ../secrets/openai-key;

    nix-access-tokens = {
      file = ../secrets/nix-access-tokens;
      # Explicitly set path, the default include an env var reference to $XDG_CONFIG_HOME
      # instead of the resolved path, which is not allowed in nix configuration.
      path = "${config.xdg.configHome}/agenix/nix-access-tokens";
    };
    google-account = {
      file = ../secrets/google-account;
      path = "${config.xdg.configHome}/agenix/google-account";
    };
    prr-global = {
      file = ../secrets/prr-global;
      path = "${config.xdg.configHome}/prr/config.toml";
    };
    npm-token = {
      file = ../secrets/npm-token;
      path = "/home/lotus/.npmrc";
    };
  };
}
