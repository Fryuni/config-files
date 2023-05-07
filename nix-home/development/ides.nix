{pkgs, ...}: {
  home.packages = with pkgs; [
    jetbrains.pycharm-professional
    jetbrains.goland
    jetbrains.webstorm
    jetbrains.datagrip
    jetbrains.idea-ultimate
    # android-studio

    postman
    altair
  ];
}
