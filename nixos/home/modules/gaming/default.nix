{ pkgs, ... }:
{
  home.packages = with pkgs; [
    polymc
  ];
}
