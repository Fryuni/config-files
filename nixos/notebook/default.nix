{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ../modules/development.nix
    ../modules/gaming.nix
    ../modules/networking/tailscale.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.blacklistedKernelModules = ["ideapad_laptop"];
  boot.extraModulePackages = with config.boot.kernelPackages; [zenpower];

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv6l-linux"
    "armv7l-linux"
  ];

  networking = {
    hostName = "note";
    # Avoid unreliable association/autoconnect behavior on the notebook.
    networkmanager.wifi.powersave = false;
  };

  services.vmagent.enable = true;
  services.autorandr = {
    enable = true;
    defaultTarget = "horizontal";
    hooks.postswitch.set-wallpaper = ''
      ${pkgs.feh}/bin/feh --bg-fill /home/lotus/.background-image
    '';

    profiles = {
      docked = {
        fingerprint = {
          HDMI-0 = "00ffffffffffff001e6d4f7701010101011e010380462878ea7ba1ae4f44a9260c5054210800d1c0614045400101010101010101010108e80030f2705a80b0588a00b9882100001e000000fd00283c1e873c000a202020202020000000fc004c472048445220344b0a202020000000ff000a20202020202020202020202001de0203427223090707830100004d01030410121f202261605f5e5d6d030c001000b83c20006001020367d85dc401788003e30f0003e2006ae305c000e606050159595204740030f2705a80b0588a00b9882100001e565e00a0a0a0295030203500b9882100001a1a3680a070381f402a263500b9882100001a0000000000000019";
          eDP-1-1 = "00ffffffffffff0009e5600800000000011d0104a522137802b015a75651a3280f5054000000010101010101010101010101010101015b3780cc703820403020360058c21000001a492c80cc703820403020360058c21000001a000000fe00374e564437804e5631354e345100000000000141219e001000000a010a2020003e";
        };
        config = {
          HDMI-0 = {
            enable = true;
            primary = true;
            position = "1920x0";
            mode = "3840x2160";
            rate = "60.00";
          };
          eDP-1-1 = {
            enable = true;
            position = "0x617";
            mode = "1920x1080";
            rate = "60.00";
          };
        };
      };

      mobile = {
        fingerprint = {
          eDP-1-1 = "00ffffffffffff0009e5600800000000011d0104a522137802b015a75651a3280f5054000000010101010101010101010101010101015b3780cc703820403020360058c21000001a492c80cc703820403020360058c21000001a000000fe00374e564437804e5631354e345100000000000141219e001000000a010a2020003e";
        };
        config = {
          eDP-1-1 = {
            enable = true;
            primary = true;
            position = "0x0";
            mode = "1920x1080";
            rate = "60.00";
          };
        };
      };
    };
  };

  # networking.nameservers = lib.mkForce [
  #   "45.90.28.0#G5--Note-f7fd51.dns.nextdns.io"
  #   "2a07:a8c0::#G5--Note-f7fd51.dns.nextdns.io"
  #   "45.90.30.0#G5--Note-f7fd51.dns.nextdns.io"
  #   "2a07:a8c1::#G5--Note-f7fd51.dns.nextdns.io"
  # ];
  # services.resolved.domains = lib.mkForce [
  #   "45.90.28.0#G5--Note-f7fd51.dns.nextdns.io"
  #   "2a07:a8c0::#G5--Note-f7fd51.dns.nextdns.io"
  #   "45.90.30.0#G5--Note-f7fd51.dns.nextdns.io"
  #   "2a07:a8c1::#G5--Note-f7fd51.dns.nextdns.io"
  # ];

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  users.users.lotus.hashedPassword = "$6$5dd95KPYAytsdzt1$7auK5wgcz3xGilTjmUw./Acr9tNHQDBJn6n9Ob5bgBiL.vXOQQau.5tFhuF0uGkrI.36c8SK61m/P4kBFKoy60";

  nix = {
    settings = {
      cores = 4;
      max-jobs = 2;
    };
  };

  environment.systemPackages = [
    pkgs.nix-doc
  ];

  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run;
  };

  networking.firewall.allowedTCPPorts = [22];
  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    ports = [22];
    settings = {
      AllowUsers = ["lotus" "nix-ssh"];
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      UseDns = true;
      X11Forwarding = false;
      ChallengeResponseAuthentication = "no";
    };
  };

  services.lferrazTailnetAccess.proxy.aliases.hermes = 9120;
  services.tailscale.fileInbox.enable = true;

  boot.kernel.sysctl = {
    "net.core.rmem_max" = 7500000;
    "net.core.wmem_max" = 7500000;
  };
}
