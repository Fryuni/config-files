{
  self,
  pkgs,
  homeManagerBin,
}: let
  homeManager = homeManagerBin;
  commands = let
    bins = builtins.mapAttrs (name: pkg: pkgs.lib.meta.getExe pkg) pkgs;
  in [
    # Setup
    {
      name = "activate/notebook";
      category = "setup";
      help = "Install home-manager and apply home configuration";
      command = ''
        export HOME_MANAGER_BACKUP_EXT=old
        ${self.outputs.homeConfigurations.notebook.activationPackage}/activate
      '';
    }

    # --- Home Environment ---
    {
      name = "ls-pkg";
      category = "Home";
      help = "List all packages installed in home-manager-path";
      command = ''
        ${homeManager} packages
      '';
    }
    {
      name = "ls-gen";
      category = "Home";
      help = "List all home environment generations";
      command = ''
        ${homeManager} generations
      '';
    }
    {
      name = "diff";
      category = "Home";
      help = "Compute the package difference that will be applied to home-manager on a switch";
      command = ''
        ${bins.nvd} diff \
          $(${bins.nix} eval -f ~/.nix-profile/manifest.nix --json | ${bins.jq} -r '.[0]') \
          ${self.outputs.homeConfigurations.notebook.config.home.path}
      '';
    }
    {
      name = "build";
      category = "Home";
      help = "Build home-manager configuration without applying it";
      command = ''
        ${bins.nix} build --no-link --print-out-paths .#homeConfigurations.notebook.activationPackage $@
      '';
    }
    {
      name = "switch";
      category = "Home";
      help = "Switch home-manager to apply home config changes";
      command = ''
        ${homeManager} switch --flake . -b bck $@
      '';
    }
    {
      name = "update";
      category = "Home";
      help = "Update the flake lock file only";
      command = ''
        ${bins.nix} flake update $@
        ${bins.git} restore --staged .
        ${bins.git} add flake.lock
        ${bins.git} commit -m "chore: Update flake"
      '';
    }

    # NixOS
    {
      name = "os-switch";
      category = "NixOS";
      help = "Apply NixOS configuration and configure it as the default profile";
      command = ''
        sudo nixos-rebuild switch --flake '.#notebook' $@
      '';
    }
    {
      name = "os-test";
      category = "NixOS";
      help = "Apply NixOS configuration but don't set it on any boot entry";
      command = ''
        sudo nixos-rebuild test --flake '.#notebook' $@
      '';
    }
    {
      name = "os-diff";
      category = "NixOS";
      help = "Compute the package difference that will be applied to the system on a switch";
      command = ''
        ${bins.nvd} diff \
          /run/current-system \
          ${self.outputs.nixosConfigurations.notebook.config.system.build.toplevel}
      '';
    }
    {
      name = "os-build";
      category = "NixOS";
      help = "Build NixOS configuration without applying";
      command = ''
        echo "${self.outputs.nixosConfigurations.notebook.config.system.build.toplevel}"
      '';
    }
    {
      name = "os-boot";
      category = "NixOS";
      help = "Apply NixOS configuration as the default boot profile, but don't load it immediately";
      command = ''
        sudo nixos-rebuild boot --flake '.#notebook' $@
      '';
    }
    {
      name = "os-boot-offline";
      category = "NixOS";
      help = "Apply NixOS configuration as the default boot profile, but don't load it immediately";
      command = ''
        sudo nixos-rebuild boot --flake '.#notebook' --option substitute false $@
      '';
    }
    {
      name = "os-purge";
      category = "NixOS";
      help = "Drop a system profile and purges it from the bootloader";
      command = ''
        sudo rm -vrf /nix/var/nix/profiles/system-profiles/$1 /nix/var/nix/profiles/system-profiles/$1-*-link
        sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
      '';
    }

    # Utility
    {
      name = "clear";
      category = "Utility";
      help = "Clear build result";
      command = ''
        rm -rf ./result
      '';
    }
    {
      name = "fmt";
      category = "Utility";
      help = "Format nix files";
      command = ''
        ${bins.statix} fix
        ${bins.nix} fmt $@
      '';
    }
    {
      name = "gc";
      category = "Utility";
      help = "Garbage collection";
      command = ''
        sudo nix-collect-garbage $@
      '';
    }
    {
      name = "gc-all-gen";
      category = "Utility";
      help = ''Delete old generations and garbage collection'';
      command = ''
        rm -rf ./result
        ${homeManager} expire-generations now || true
        sudo nix-collect-garbage -d $@
      '';
    }
  ];
  commandToApp = cmd: {
    inherit (cmd) name;
    value = {
      type = "app";
      program = builtins.toString (pkgs.writeShellScript cmd.name cmd.command);
    };
  };
  appList = builtins.map commandToApp commands;
in
  builtins.listToAttrs appList
