{pkgs, ...}: {
  home.packages = with pkgs; [
    sublime4
    dbeaver

    jetbrains.pycharm-professional
    jetbrains.goland
    jetbrains.webstorm
    jetbrains.datagrip
    jetbrains.idea-ultimate
    android-studio

    postman
    altair
  ];
}
