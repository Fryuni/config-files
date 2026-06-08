{
  pkgs,
  lib,
  ...
}: {
  # Sunshine is a graphical-session user service. Auto-login starts the
  # Hyprland session after boot so Sunshine is reachable without first
  # unlocking the local console.
  services.displayManager.autoLogin = {
    enable = lib.mkDefault true;
    user = lib.mkDefault "lotus";
  };

  environment.variables = {
    GAMEMODERUNEXEC = "mangohud WINEFSYNC=1 PROTON_WINEDBG_DISABLE=1 DXVK_LOG_PATH=none DXVK_HUD=compiler ALSOFT_DRIVERS=alsa";
  };

  environment.systemPackages = with pkgs; [
    # Gaming
    mangohud
    # minecraft
    mesa-demos
    lutris
    dconf
    stable.bottles
    vulkan-tools
    winetricks
    # nix-gaming.packages.x86_64-linux.wine-tkg
    # nix-gaming.packages.x86_64-linux.wine-tkg.dev
    wine64
  ];

  programs.gamemode.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;

    package = pkgs.steam.override {
      extraPkgs = pkgs: with pkgs; [gamemode mangohud];
    };
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;
    capSysAdmin = true; # required for DRM/KMS capture
    settings = {
      # wlr capture uses Hyprland's wlroots screencopy path. On this hybrid
      # Intel/NVIDIA host, Hyprland 0.55.2 can abort in copyDmabuf/explicit-sync
      # as soon as Moonlight connects. KMS capture avoids the compositor
      # screencopy path and Sunshine already has CAP_SYS_ADMIN above.
      capture = "kms";
    };
  };

  # Let FFmpeg/NVENC find the NVIDIA userspace driver libraries when Sunshine
  # is launched as a systemd user service through the NixOS security wrapper.
  systemd.user.services.sunshine.environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";

  users.users.lotus.extraGroups = ["uinput"];

  services.udev.extraRules = ''
    # This rule is needed for basic functionality of the controller in
    # Steam and keyboard/mouse emulation
    SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"
    # This rule is necessary for gamepad emulation; the user that runs Steam and
    # Sunshine belongs to the uinput group.
    KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
    # Valve HID devices over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0666"
    # Valve HID devices over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*28DE:*", MODE="0666"
    # DualShock 4 over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0666"
    # Dualsense over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0666"
    # DualShock 4 wireless adapter over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ba0", MODE="0666"
    # DualShock 4 Slim over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0666"
    # DualShock 4 over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*054C:05C4*", MODE="0666"
    # DualShock 4 Slim over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*054C:09CC*", MODE="0666"
  '';
}
