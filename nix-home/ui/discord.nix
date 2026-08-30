{
  pkgs,
  lib,
  ...
}: let
  base-discord = pkgs.stable.discord;

  discord-vpn-starter = pkgs.writeShellApplication {
    name = "discord-vpn";
    runtimeInputs = [pkgs.jq pkgs.procps];
    text = ''
      pkill -9 Discord || true

      if ! (tailscale status --self --json | jq -e .ExitNodeStatus > /dev/null); then
        tailscale up --exit-node loem
        (sleep 10; tailscale up --exit-node "") & disown
      fi

      exec Discord
    '';
  };

  desktop-entry = pkgs.makeDesktopItem {
    type = "Application";
    name = "discord";
    desktopName = "Discord With VPN start";
    comment = "Start Discord behind an Exit Node from Tailscale";
    exec = lib.getExe discord-vpn-starter;
    icon = "discord";
    categories = ["Network" "InstantMessaging"];
    mimeTypes = ["x-scheme-handler/discord"];
    startupWMClass = "discord";
  };
in {
  home.packages = [
    base-discord
    discord-vpn-starter
    (lib.hiPrio desktop-entry)
  ];
}
