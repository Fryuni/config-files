{pkgs, ...}: {
  users.mutableUsers = false;

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

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILI4D6ddYz7WosKUA4Xr7R1cwLF/mpCSWrCSW3O9Ct7E luiz@lferraz.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYY0uHuJGkwcZOsZLqUgdNw6FMxYkz5pY0YeUgmr8dw luiz@lferraz.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICphbHvsvJiWjPAV8+JlUZfMHZtXIcp9L+cxn6Y9pjBZ"
    ];
  };

  programs.zsh.enable = true;
}
