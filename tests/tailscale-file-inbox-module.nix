{
  lib,
  pkgs,
  tailscaleFileInboxModule,
}: let
  evalModule = extraModule:
    lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      inherit pkgs;
      modules = [
        tailscaleFileInboxModule
        {
          system.stateVersion = "26.05";

          services.tailscale = {
            enable = true;
            package = pkgs.tailscale;
          };
        }
        extraModule
      ];
    };

  disabled = evalModule {};
  defaultEnabled = evalModule {
    services.tailscale.fileInbox.enable = true;
  };
  customPath = evalModule {
    services.tailscale.fileInbox = {
      enable = true;
      path = "/srv/taildrop-inbox";
    };
  };

  disabledCfg = disabled.config;
  defaultCfg = defaultEnabled.config;
  customCfg = customPath.config;
  defaultService = defaultCfg.systemd.services."tailscale-file-inbox";
  defaultServiceConfig = defaultService.serviceConfig;
  customService = customCfg.systemd.services."tailscale-file-inbox";
  customServiceConfig = customService.serviceConfig;

  configJson = builtins.toJSON {
    disabled = {
      fileInbox = disabledCfg.services.tailscale.fileInbox;
      hasService = disabledCfg.systemd.services ? tailscale-file-inbox;
      hasDefaultTmpfilesRule = builtins.elem "d /opt/tailscale-inbox 0755 root root - -" disabledCfg.systemd.tmpfiles.rules;
    };
    defaultEnabled = {
      fileInbox = defaultCfg.services.tailscale.fileInbox;
      inherit (defaultService) after requires wantedBy wants;
      inherit (defaultServiceConfig) ExecStart Restart RestartSec WorkingDirectory;
      tmpfilesRules = defaultCfg.systemd.tmpfiles.rules;
    };
    customPath = {
      fileInbox = customCfg.services.tailscale.fileInbox;
      inherit (customServiceConfig) ExecStart WorkingDirectory;
      tmpfilesRules = customCfg.systemd.tmpfiles.rules;
    };
  };
in
  pkgs.runCommand "tailscale-file-inbox-module-check" {
    nativeBuildInputs = [pkgs.jq];
    inherit configJson;
  } ''
    printf '%s\n' "$configJson" > config.json

    jq -e '.disabled.fileInbox.enable == false' config.json
    jq -e '.disabled.fileInbox.path == "/opt/tailscale-inbox"' config.json
    jq -e '.disabled.hasService == false' config.json
    jq -e '.disabled.hasDefaultTmpfilesRule == false' config.json

    jq -e '.defaultEnabled.fileInbox.enable == true' config.json
    jq -e '.defaultEnabled.fileInbox.path == "/opt/tailscale-inbox"' config.json
    jq -e '.defaultEnabled.tmpfilesRules | any(. == "d /opt/tailscale-inbox 0755 root root - -")' config.json
    jq -e '.defaultEnabled.wantedBy == ["multi-user.target"]' config.json
    jq -e '.defaultEnabled.after | index("tailscaled.service")' config.json
    jq -e '.defaultEnabled.after | index("network-online.target")' config.json
    jq -e '.defaultEnabled.wants | index("tailscaled.service")' config.json
    jq -e '.defaultEnabled.wants | index("network-online.target")' config.json
    jq -e '.defaultEnabled.requires == ["tailscaled.service"]' config.json
    jq -e '.defaultEnabled.WorkingDirectory == "/opt/tailscale-inbox"' config.json
    jq -e '.defaultEnabled.Restart == "always"' config.json
    jq -e '.defaultEnabled.RestartSec == "10s"' config.json
    jq -e '.defaultEnabled.ExecStart | contains("/bin/tailscale file get --loop --wait --conflict=rename /opt/tailscale-inbox")' config.json

    jq -e '.customPath.fileInbox.enable == true' config.json
    jq -e '.customPath.fileInbox.path == "/srv/taildrop-inbox"' config.json
    jq -e '.customPath.tmpfilesRules | any(. == "d /srv/taildrop-inbox 0755 root root - -")' config.json
    jq -e '.customPath.WorkingDirectory == "/srv/taildrop-inbox"' config.json
    jq -e '.customPath.ExecStart | contains("/bin/tailscale file get --loop --wait --conflict=rename /srv/taildrop-inbox")' config.json

    touch "$out"
  ''
