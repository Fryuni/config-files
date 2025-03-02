{...}: {
  imports = [
    ../common.nix
    ../modules/rpi3.nix
  ];

  networking = {
    hostName = "rpi-one";

    wireless.enable = false;
    useDHCP = true;
    interfaces = {
      eth0.useDHCP = true;
    };
    firewall.enable = false;
  };
}
