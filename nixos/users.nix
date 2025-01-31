{pkgs, ...}: {
  users.users.lotus = {
    uid = 1000;
    isNormalUser = true;
    description = "Void Lotus";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "wireshark"
      "audio"
      "rtkit"
      "dialout"
    ];

    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}
