{config, ...}: {
  age.secrets = {
    github-key.file = ../secrets/github-key;
    habitica-key.file = ../secrets/habitica-key;
    openai-key.file = ../secrets/openai-key;

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
