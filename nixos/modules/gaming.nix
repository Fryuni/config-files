{
  pkgs,
  nixpkgs,
  ...
}: {
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
    bottles
    vulkan-tools
    winetricks
    # nix-gaming.packages.x86_64-linux.wine-tkg
    # nix-gaming.packages.x86_64-linux.wine-tkg.dev
    wine
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

  services.udev.extraRules = ''
    # This rule is needed for basic functionality of the controller in
    # Steam and keyboard/mouse emulation
    SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"
    # This rule is necessary for gamepad emulation; make sure you
    # replace 'pgriffais' with a group that the user that runs Steam
    # belongs to
    KERNEL=="uinput", MODE="0660", GROUP="pgriffais", OPTIONS+="static_node=uinput"
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
