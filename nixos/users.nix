{pkgs, ...}: {
  users.mutableUsers = false;

  users.users.lotus = {
    uid = 1000;
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "Void Lotus";
    hashedPassword = "$6$5dd95KPYAytsdzt1$7auK5wgcz3xGilTjmUw./Acr9tNHQDBJn6n9Ob5bgBiL.vXOQQau.5tFhuF0uGkrI.36c8SK61m/P4kBFKoy60";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "wireshark"
      "audio"
      "rtkit"
      "dialout"
    ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw luiz@lferraz.com"
    ];
  };

  programs.zsh.enable = true;
}
