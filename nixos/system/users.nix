{ pkgs, ... }:
{
  users.mutableUsers = false;
  users.users.lotus = {
    uid = 1000;
    isNormalUser = true;
    description = "Void Lotus";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "audio"
      "rtkit"
      "dialout"
    ];

    shell = pkgs.zsh;

    hashedPassword = "$6$5dd95KPYAytsdzt1$7auK5wgcz3xGilTjmUw./Acr9tNHQDBJn6n9Ob5bgBiL.vXOQQau.5tFhuF0uGkrI.36c8SK61m/P4kBFKoy60";
  };
}
