{pkgs, ...}: {
  imports = [
  ];

  home.packages = with pkgs; [
    postgresql_16_jit
  ];

  programs.ssh.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;
}
