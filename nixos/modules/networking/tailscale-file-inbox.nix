{
  config,
  lib,
  ...
}: let
  cfg = config.services.tailscale.fileInbox;
  tailscale = config.services.tailscale.package;
in {
  options.services.tailscale.fileInbox = {
    enable = lib.mkEnableOption "the Taildrop file inbox service";

    path = lib.mkOption {
      type = lib.types.str;
      default = "/opt/tailscale-inbox";
      description = ''
        Directory where received Taildrop files are moved by
        `tailscale file get --loop --wait`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "services.tailscale.fileInbox.enable requires services.tailscale.enable.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.path;
        message = "services.tailscale.fileInbox.path must be an absolute path.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0755 root root - -"
    ];

    systemd.services.tailscale-file-inbox = {
      description = "Receive Taildrop files into ${cfg.path}";
      wantedBy = ["multi-user.target"];
      after = ["tailscaled.service" "network-online.target"];
      wants = ["tailscaled.service" "network-online.target"];
      requires = ["tailscaled.service"];

      serviceConfig = {
        ExecStart = "${tailscale}/bin/tailscale file get --loop --wait --conflict=rename ${cfg.path}";
        Restart = "always";
        RestartSec = "10s";
        WorkingDirectory = cfg.path;
      };
    };
  };
}
