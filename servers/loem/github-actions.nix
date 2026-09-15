{
  config,
  lib,
  pkgs,
  ...
}: let
  registrations = import ./github-actions-runners.nix;
  credentials = lib.unique (lib.attrValues registrations);
  secretName = credential: "github-actions-${credential}-token";
  secretSource = credential: ../../secrets/loem + "/${secretName credential}";
  # Bootstrap without committing dummy secrets. Once an encrypted source is
  # added and rekeyed, agenix takes over from the provisioned root-only file.
  encryptedCredentials = lib.filter (credential: builtins.pathExists (secretSource credential)) credentials;
  runnerName = scope:
    (
      if lib.hasInfix "/" scope
      then "repo-"
      else "org-"
    )
    + lib.toLower (lib.replaceStrings ["/"] ["-"] scope);
in {
  assertions = [
    {
      assertion = let
        names = map runnerName (lib.attrNames registrations);
      in
        lib.length names == lib.length (lib.unique names);
      message = "GitHub runner scopes must produce distinct service names.";
    }
  ];

  age.secrets = lib.genAttrs (map secretName encryptedCredentials) (name: {
    rekeyFile = ../../secrets/loem + "/${name}";
    owner = "root";
    group = "root";
    mode = "0400";
  });

  services.github-runners = lib.mapAttrs' (scope: credential:
    lib.nameValuePair (runnerName scope) {
      enable = true;
      name = "${config.networking.hostName}-${runnerName scope}";
      url = "https://github.com/${scope}";
      tokenFile =
        if lib.elem credential encryptedCredentials
        then config.age.secrets.${secretName credential}.path
        else "/var/lib/github-runner-tokens/${credential}";
      tokenType = "access";
      replace = true;
      extraLabels = ["nix" "nixos" "docker" config.networking.hostName];
      extraPackages = with pkgs; [bash coreutils curl docker gawk gitMinimal gnused nix nodejs wget];
      # Keep checkouts on disk and visible at the same path to host Docker.
      workDir = "/var/lib/github-runner-work/${runnerName scope}";
      serviceOverrides = {
        StateDirectory = ["github-runner-work/${runnerName scope}"];
        SupplementaryGroups = ["docker"];
        PrivateUsers = false;
      };
    })
  registrations;

  systemd.services = lib.mapAttrs' (scope: _:
    lib.nameValuePair "github-runner-${runnerName scope}" {
      wants = ["docker.service"];
      after = ["docker.service"];
    })
  registrations;

  systemd.tmpfiles.rules = lib.optional (registrations != {}) "d /var/lib/github-runner-tokens 0700 root root -";
}
