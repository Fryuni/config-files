{
  description = "Fryuni's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    polymc = {
      url = "github:PolyMC/PolyMC";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    flake-utils,
    devshell,
    ...
  } @ attrs: let
    pkgFun = system: let
      pkgConfig = {
        inherit system;
        config.allowUnfree = true;
      };
    in
      import nixpkgs (pkgConfig
        // {
          overlays = [
            (_: _: {
              master = import attrs.nixpkgs-master pkgConfig;
              stable = import attrs.nixpkgs-stable pkgConfig;
            })
            (import ./overlay)
            attrs.polymc.overlay
            devshell.overlay
          ];
        });

    pkgs = pkgFun builtins.currentSystem;
  in
    {
      nixosConfigurations.notebook = nixpkgs.lib.nixosSystem {
        system = builtins.currentSystem;
        specialArgs = {
          inherit pkgs;
          inputs = attrs;
        };
        modules = [
          ./nixos
          ./nixos/notebook
        ];
      };

      homeConfigurations.notebook = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./nix-home
          ./nix-home/notebook.nix
        ];
      };
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = pkgFun system;
    in {
      formatter = pkgs.alejandra;

      apps = {
        "activate/notebook" = {
          type = "app";
          program = "${self.outputs.homeConfigurations.notebook.activationPackage}/activate";
        };
      };

      devShells.default = pkgs.devshell.mkShell {
        devshell.motd = ''
          {bold}{14}🔨 Management commands 🔨{reset}
          $(type -p menu &>/dev/null && menu)
        '';

        commands = [
          # Setup
          {
            name = "install-notebook";
            category = "setup";
            help = "Install home-manager and apply home configuration";
            command = ''
              export HOME_MANAGER_BACKUP_EXT=old
              nix run '.#activate/notebook'
            '';
          }

          # --- Home Environment ---
          {
            name = "ls-pkg";
            category = "Home";
            help = "List all packages installed in home-manager-path";
            command = ''
              home-manager packages
            '';
          }
          {
            name = "ls-gen";
            category = "Home";
            help = "List all home environment generations";
            command = ''
              home-manager generations
            '';
          }
          {
            name = "diff";
            category = "Home";
            help = "Compute the package difference that will be applied to home-manager on a switch";
            command = ''
              build
              ${pkgs.nvd}/bin/nvd diff /nix/var/nix/profiles/per-user/$USER/home-manager ./result
            '';
          }
          {
            name = "build";
            category = "Home";
            help = "Build home-manager configuration without applying it";
            command = ''
              home-manager build --flake '.#notebook' -b bck --impure $@
            '';
          }
          {
            name = "switch";
            category = "Home";
            help = "Switch home-manager to apply home config changes";
            command = ''
              home-manager switch --flake '.#notebook' -b bck --impure $@
            '';
          }
          {
            name = "update";
            category = "Home";
            help = "Update the flake lock file only";
            command = ''
              nix flake update $@
            '';
          }

          # NixOS
          {
            name = "os-switch";
            category = "NixOS";
            help = "Apply NixOS configuration and configure it as the default profile";
            command = ''
              sudo nixos-rebuild switch --flake '.#notebook' --impure $@
            '';
          }
          {
            name = "os-test";
            category = "NixOS";
            help = "Apply NixOS configuration but don't set it on any boot entry";
            command = ''
              sudo nixos-rebuild test --flake '.#notebook' --impure $@
            '';
          }
          {
            name = "os-diff";
            category = "NixOS";
            help = "Compute the package difference that will be applied to the system on a switch";
            command = ''
              os-build
              ${pkgs.nvd}/bin/nvd diff /run/current-system ./result
            '';
          }
          {
            name = "os-build";
            category = "NixOS";
            help = "Build NixOS configuration without applying";
            command = ''
              nixos-rebuild build --flake '.#notebook' --impure $@
            '';
          }
          {
            name = "os-boot";
            category = "NixOS";
            help = "Apply NixOS configuration as the default boot profile, but don't load it immediately";
            command = ''
              sudo nixos-rebuild boot --flake '.#notebook' --impure $@
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
              sudo nix-collect-garbage -d $@
            '';
          }
        ];
      };
    });
}
