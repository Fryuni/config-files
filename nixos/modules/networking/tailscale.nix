{
  config,
  pkgs,
  ...
}: let
  package = pkgs.master.tailscale;
in {
  # make the tailscale command usable to users
  environment.systemPackages = [package];

  # enable the tailscale service
  services.tailscale = {
    inherit package;
    enable = true;
    useRoutingFeatures = "both";
  };

  networking.firewall = {
    # always allow traffic from your Tailscale network
    trustedInterfaces = [config.services.tailscale.interfaceName];

    # allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [config.services.tailscale.port];
  };
}
