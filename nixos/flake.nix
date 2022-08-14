{
  description = "Fryuni's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
  };

  outputs = { self, nixpkgs, home-manager, flake-utils, devshell, ... }@attrs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      formatter.x86_64-linux = pkgs.nixpkgs-fmt;

      nixosConfigurations.notebook = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = attrs;
        modules = [
          ./system
          ./system/notebook
        ];
      };

      homeConfiguration.notebook = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./home
        ];
      };

      apps.${system} = {
        "activate/notebook" = {
          type = "app";
          program = "${self.outputs.homeConfigurations.notebook.activationPackage}}/activate";
        };
      };
    } //
    flake-utils.lib.eachDefaultSystem (system: {
      devShell =
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ devshell.overlay ];
          };
        in
        pkgs.devshell.mkShell {
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

            # NixOS
            {
              name = "os-switch";
              category = "NixOS";
              help = "Apply NixOS configuration and configure it as the default profile";
              command = ''
                sudo nixos-rebuild switch --flake '.#notebook' --impure
              '';
            }
            {
              name = "os-test";
              category = "NixOS";
              help = "Apply NixOS configuration but don't set it on any boot entry";
              command = ''
                sudo nixos-rebuild test --flake '.#notebook' --impure
              '';
            }
            {
              name = "os-build";
              category = "NixOS";
              help = "Build NixOS configuration without applying";
              command = ''
                sudo nixos-rebuild build --flake '.#notebook' --impure
              '';
            }
            {
              name = "os-boot";
              category = "NixOS";
              help = "Apply NixOS configuration as the default boot profile, but don't load it immediately";
              command = ''
                sudo nixos-rebuild build --flake '.#notebook' --impure
              '';
            }

            # Utility
            {
              name = "hello";
              category = "Utility";
              help = "Print a nice hello world";
              command = ''
                nix run 'nixpkgs#figlet' -- -f isometric1 -c "Hello World"
              '';
            }
            {
              name = "fmt";
              category = "Utility";
              help = "Format nix files";
              command = ''
                nix fmt
              '';
            }
            {
              name = "gc";
              category = "Utility";
              help = "Garbage collection";
              command = ''
                sudo nix-collect-garbage
              '';
            }
            {
              name = "gc-all-gen";
              category = "Utility";
              help = ''Delete old generations and garbage collection'';
              command = ''
                sudo nix-collect-garbage -d
              '';
            }
          ];
        };
    });
}
