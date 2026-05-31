{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./nix-settings.nix
    ./modules/networking
    ./modules/hyprland.nix
    ./modules/honcho.nix
    ./users.nix
    ./audio.nix
    ./registries.nix
    ./sshHosts.nix
  ];

  # Set your time zone.
  time.timeZone = "America/Sao_Paulo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Display manager - SDDM with Wayland support
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  # Default to Hyprland session (can also select Plasma from SDDM)
  services.displayManager.defaultSession = "hyprland";

  # Keep Plasma available as an alternative
  services.desktopManager.plasma6.enable = true;

  # DrKonqi's systemd-coredump integration is currently crashing on GUI login
  # while replaying coredumps accumulated before the graphical session starts.
  # Keep systemd-coredump storage available, but stop the Plasma notification
  # bridge from picking up and launching notifications for those dumps.
  systemd.services."drkonqi-coredump-processor@".enable = false;
  systemd.user.services = {
    "drkonqi-coredump-launcher@".enable = false;
    drkonqi-coredump-pickup.enable = false;
  };
  systemd.user.sockets.drkonqi-coredump-launcher.enable = false;

  # services.xserver.desktopManager.xfce.enable = true;
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };
  services.gvfs.enable = true; # Enable automounting for removable media
  services.tumbler.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
  };

  # Configure console keymap
  console.keyMap = "us";

  # Temporary hardening for CVE-2026-46333 until all systems boot a fixed kernel.
  # 3 disables ptrace attachment entirely, including same-UID debugging.
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 3;

  # Enable CUPS to print documents.
  services.printing.enable = false;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    wget
    git
    dig
    htop
    btop
    gnumake
    xarchiver
    cachix
    agenix
    bubblewrap
    socat
  ];

  # xdg.portal.enable = true;
  # services.flatpak.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "26.05";
  system.autoUpgrade.enable = true;
}
