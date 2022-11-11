{ config, pkgs, lib, ... }:
with lib;
{
  # Enable networking
  networking.networkmanager.enable = true;

  networking.enableIPv6 = false;

  services.openvpn.servers =
    let
      nordModeNames = builtins.attrNames (builtins.readDir ./nordvpn);

      nordModeToFiles = mode:
        let
          modeFiles = builtins.attrNames (builtins.readDir "${./nordvpn}/${mode}");
        in
        builtins.map
          (file:
            let
              nameParts = strings.splitString "." file;
            in
            {
              provider = "nord";
              protocol = builtins.elemAt nameParts 3;
              name = builtins.elemAt nameParts 0;
              configFile = "${./nordvpn}/${mode}/${file}";
            })
          modeFiles;

      nordServers = lists.flatten (builtins.map nordModeToFiles nordModeNames);

      configs = builtins.map
        (server: {
          name = "${server.provider}.${server.protocol}.${server.name}";
          value = {
            # authUserPass.username = "luiz@lferraz.com";
            autoStart = false;
            config = "config ${server.configFile}";
          };
        })
        nordServers;
    in
    builtins.listToAttrs configs;
}
