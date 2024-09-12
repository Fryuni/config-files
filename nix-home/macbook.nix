{...}: {
  imports = [ ./default.nix ];

  # home.username = "lotus";
  # home.homeDirectory = "/Users/lotus";

  programs.ssh.enable = true;
  programs.gpg.enable = true;
  programs.gpg.mutableKeys = true;
}
