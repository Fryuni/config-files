{pkgs, ...}: {
  home.packages = with pkgs; [
    jetbrains.pycharm-professional
    jetbrains.goland
    # jetbrains.rust-rover
    jetbrains.webstorm
    jetbrains.datagrip
    jetbrains.idea-ultimate
    # android-studio

    insomnia
  ];
}
