{ pkgs, libs, ... }:
{
  environment.variables.EDITOR = "nvim";

  documentation.dev.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    inotify-tools
    ripgrep
    cargo
    rust-analyzer
    rustfmt
    rustc
    gcc
    jq
    fd
    xdelta
  ];

  systemd.enableUnifiedCgroupHierarchy = true;

  virtualisation = {
    containerd.enable = true;

    docker = {
      enable = true;

      autoPrune.enable = true;
      autoPrune.dates = "weekly";
      autoPrune.flags = [ "--all" ];
    };
  };
}
