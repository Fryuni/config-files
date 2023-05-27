{
  description = "Fryuni's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    polymc = {
      url = "github:PolyMC/PolyMC";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    fenix,
    # nixos-hardware,
    home-manager,
    flake-utils,
    devshell,
    ...
  } @ attrs: let
    pkgsFun = system:
      let
        stable = import attrs.nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
          config.permittedInsecurePackages = [];
        };
        master = import attrs.nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
          config.permittedInsecurePackages = [];
        };
      in
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [];
        overlays = [
          (_: _: { inherit stable master; })
          fenix.overlays.default
          (import ./overlay)
          # attrs.polymc.overlay
          # devshell.overlay
        ];
      };

    globalConfig = {
      templates = import ./templates attrs;

      nixosConfigurations.notebook = nixpkgs.lib.nixosSystem rec {
        system = flake-utils.lib.system.x86_64-linux;
        pkgs = pkgsFun system;
        specialArgs = {
          inputs = attrs;
        };

        modules = [
          ./nixos
          ./nixos/notebook
          # nixos-hardware.nixosModules.dell-g3-3779
        ];
      };

      homeConfigurations.notebook = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFun flake-utils.lib.system.x86_64-linux;
        extraSpecialArgs = {
          inputs = attrs;
        };

        modules = [
          ./nix-home
          ./nix-home/notebook.nix
        ];
      };

      pkgs = pkgsFun flake-utils.lib.system.x86_64-linux;
    };

    perSystemConfig = flake-utils.lib.eachDefaultSystem (system: let
      pkgs = pkgsFun system;

      homeManager = "${home-manager.packages.${system}.home-manager}/bin/home-manager";
      commands = [
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
            ${pkgs.nvd}/bin/nvd diff \
              /nix/var/nix/profiles/per-user/$USER/home-manager \
              ${self.outputs.homeConfigurations.notebook.activationPackage}
          '';
        }
        {
          name = "build";
          category = "Home";
          help = "Build home-manager configuration without applying it";
          command = ''
            nix build --no-link --print-out-paths .#homeConfigurations.notebook.activationPackage $@
          '';
        }
        {
          name = "switch";
          category = "Home";
          help = "Switch home-manager to apply home config changes";
          command = ''
            ${homeManager} switch --flake '.#notebook' -b bck $@
          '';
        }
        {
          name = "update";
          category = "Home";
          help = "Update the flake lock file only";
          command = ''
            nix flake update $@
            git restore --staged .
            git add flake.lock
            git commit -m "chore: Update flake"
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
            ${pkgs.nvd}/bin/nvd diff \
              /run/current-system \
              ${self.outputs.nixosConfigurations.notebook.config.system.build.toplevel}
          '';
        }
        {
          name = "os-build";
          category = "NixOS";
          help = "Build NixOS configuration without applying";
          command = ''
            nix build --no-link .#nixosConfigurations.notebook.config.system.build.toplevel $@
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
            ${pkgs.statix}/bin/statix fix
            nix fmt $@
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
            sudo nix-collect-garbage -d $@
          '';
        }
      ];
    in {
      legacyPackages = pkgs;

      formatter = pkgs.alejandra;

      apps = let
        commandToApp = cmd: {
          inherit (cmd) name;
          value = {
            type = "app";
            program = builtins.toString (pkgs.writeShellScript cmd.name cmd.command);
          };
        };
        appList = builtins.map commandToApp commands;
      in
        builtins.listToAttrs appList;

      devShells.default = pkgs.devshell.mkShell {
        devshell.motd = ''
          {bold}{14}🔨 Management commands 🔨{reset}
          $(type -p menu &>/dev/null && menu)
        '';

        commands =
          builtins.map
          (cmd:
            cmd
            // {
              command = self.outputs.apps.${system}.${cmd.name}.program;
            })
          commands;
      };
    });
  in
    globalConfig // perSystemConfig;
}
