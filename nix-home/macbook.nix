{pkgs, ...}: {
  imports = [
  ];

  home.packages = with pkgs; [
    postgresql_16_jit
    # calibre
  ];

  programs.ssh.enable = true;
  programs.gpg = {
    enable = true;
    mutableKeys = true;
    settings = {
      keyid-format = "short";
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;

    config = {
      global = {
        load_dotenv = true;
      };
    };
  };
}
