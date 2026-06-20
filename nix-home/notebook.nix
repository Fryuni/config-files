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
    google-workspace-cli
  ];

  programs.home-manager.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "vps1" = {
        User = "fedora";
        IdentitiesOnly = true;
      };
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "auto";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "300";
      };
    };
  };

  services.gpg-agent.enable = true;
  services.gpg-agent.pinentry.package = pkgs.pinentry-rofi;

  hermes = {
    enabled = true;
    gateway.enabled = true;
    dashboard = {
      enabled = true;
      tailscaleService = "hermes";
    };
  };

  age.secrets.node-red-key.file = ../secrets/node-red-key;

  nix.package = pkgs.nix;

  services.agentsview = {
    enable = true;
    publicOrigin = "https://aview.note.lferraz.dev";
  };

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
