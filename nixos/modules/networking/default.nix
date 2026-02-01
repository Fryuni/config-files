{
  config,
  pkgs,
  lib,
  ...
}: {
  networking = {
    # nameservers = [
    #   "45.90.28.0#f7fd51.dns.nextdns.io"
    #   "2a07:a8c0::#f7fd51.dns.nextdns.io"
    #   "45.90.30.0#f7fd51.dns.nextdns.io"
    #   "2a07:a8c1::#f7fd51.dns.nextdns.io"
    # ];
    enableIPv6 = true;
    resolvconf.enable = false;
    dhcpcd.extraConfig = "nohook resolv.conf";
    networkmanager = {
      enable = true;
    };

    firewall = {enable = true;};
  };

  # Allow for captive portal while using encrypted DNS
  programs.captive-browser = {
    enable = true;
    interface = "wlp61s0";
  };

  services.resolved = {
    enable = true;
    # dnsovertls = "true";
    # domains = [
    #   "45.90.28.0#f7fd51.dns.nextdns.io"
    #   "2a07:a8c0::#f7fd51.dns.nextdns.io"
    #   "45.90.30.0#f7fd51.dns.nextdns.io"
    #   "2a07:a8c1::#f7fd51.dns.nextdns.io"
    # ];
    # fallbackDns = ["1.1.1.1" "8.8.8.8" "1.0.0.1" "8.8.4.4"];
  };

  services.fail2ban.enable = false;
}
