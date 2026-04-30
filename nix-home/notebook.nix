{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./ui
    ./gaming
    ./terminal
    ./development
  ];

  home.packages = with pkgs; [
    master.bitwarden-cli
    master.bitwarden-menu
    master.qbittorrent
  ];

  programs.home-manager.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "vps1" = {
        user = "fedora";
        identitiesOnly = true;
      };
      "*" = {
        forwardAgent = false;
        addKeysToAgent = "no";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "auto";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "300";
      };
    };
  };

  services.gpg-agent.enable = true;
  services.gpg-agent.pinentry.package = pkgs.pinentry-rofi;

  age.secrets.node-red-key.file = ../secrets/node-red-key;

  nix.package = pkgs.nix;

  services.node-red = {
    enable = true;
    configFile = "${../common/node-red.js}";
    repo = "git@gitlab.com:Fryuni/node-red-config.git";
    environment = {
      CREDENTIALS_FILE = config.age.secrets.node-red-key.path;
      GOOGLE_APPLICATION_CREDENTIALS = "${config.home.homeDirectory}/IsoWorkspaces/Croct/prod-env-deployer.json";
      CLOUDSDK_ACTIVE_CONFIG_NAME = "croct-sa";
    };
    # define = {
    #   "logging.console.level" = "trace";
    # };
  };
}
