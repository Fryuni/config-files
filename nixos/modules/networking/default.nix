{
  config,
  pkgs,
  lib,
  ...
}: {
  services.nordvpn.enable = true;

  networking = {
    nameservers = ["127.0.0.1" "::1"];
    enableIPv6 = true;
    resolvconf.enable = false;
    dhcpcd.extraConfig = "nohook resolv.conf";
    networkmanager = {
      enable = true;
      dns = "none";
    };
  };

  services = {
    resolved.enable = false;
    dnscrypt-proxy2 = {
      enable = true;
      settings = {
        ipv6_servers = true;
        require_dnssec = true;
        listen_addresses = ["127.0.0.1:53" "[::1]:53"];

        server_names = ["NextDNS"];

        # Generate stamps with device ID on https://dnscrypt.info/stamps/
        # static.NextDNS.stamp = "sdns://AgEAAAAAAAAAAAAOZG5zLm5leHRkbnMuaW8HL2Y3ZmQ1MQ";

        sources = {};
        # bootstrap_resolvers = [];
      };
    };
  };

  systemd.services.dnscrypt-proxy2.serviceConfig = {
    StateDirectory = "dnscrypt-proxy";
  };

  services.openvpn.servers = with lib; let
    nordModeNames = builtins.attrNames (builtins.readDir ./nordvpn);

    nordModeToFiles = mode: let
      modeFiles = builtins.attrNames (builtins.readDir "${./nordvpn}/${mode}");
    in
      builtins.map
      (file: let
        nameParts = strings.splitString "." file;
      in {
        provider = "nord";
        protocol = builtins.elemAt nameParts 3;
        name = builtins.elemAt nameParts 0;
        configFile = "${./nordvpn}/${mode}/${file}";
      })
      modeFiles;

    nordServers = lists.flatten (builtins.map nordModeToFiles nordModeNames);

    configs =
      builtins.map
      (server: {
        name = "${server.provider}.${server.protocol}.${server.name}";
        value = {
          autoStart = false;
          config = ''
            config ${server.configFile}
            auth-user-pass ${config.age.secrets.nordvpn-credentials.path}
          '';
        };
      })
      nordServers;
  in
    builtins.listToAttrs configs;
}
