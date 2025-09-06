{
  description = "Fryuni's NixOS configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    nixpkgs-stable.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixos-hardware.url = "https://flakehub.com/f/NixOS/nixos-hardware/0.1";

    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flakehub.url = "https://flakehub.com/f/DeterminateSystems/fh/*";

    systems.url = "github:nix-systems/default";
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1";
    flake-utils = {
      url = "https://flakehub.com/f/numtide/flake-utils/0.1";
      inputs.systems.follows = "systems";
    };
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs-master";
      inputs.flake-utils.follows = "flake-utils";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.systems.follows = "systems";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "https://flakehub.com/f/nix-community/fenix/0.1";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    zig = {
      url = "https://flakehub.com/f/Fryuni/zig-overlay/0.1";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.flake-compat.follows = "flake-compat";
    };
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    polymc = {
      url = "github:Fryuni/PolyMC/develop";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.flake-compat.follows = "flake-compat";
    };
    parsecgaming = {
      url = "github:DarthPJB/parsec-gaming-nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    direnv = {
      url = "github:direnv/direnv";
      inputs.nixpkgs.follows = "nixpkgs-master";
      inputs.gomod2nix.follows = "gomod2nix";
      inputs.systems.follows = "systems";
    };
    nix-alien = {
      url = "https://flakehub.com/f/thiagokokada/nix-alien/0.1";
      inputs.flake-compat.follows = "flake-compat";
    };
  };

  outputs = {
    self,
    nixpkgs,
    # nixos-hardware,
    home-manager,
    flake-utils,
    agenix,
    ...
  } @ attrs: let
    pkgsFun = system: let
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "electron-25.9.0"
        ];
        # https://github.com/NixOS/nixpkgs/pull/258447
        # https://discourse.nixos.org/t/your-system-configures-nixpkgs-with-an-externally-created-instance/33802
        pulseaudio = true;

        doCheckByDefault = false;
      };
    in
      import nixpkgs {
        inherit system config;

        overlays =
          [
            (final: _: {
              master = import attrs.nixpkgs-master {
                inherit system config;
                overlays =
                  [
                    (_: _: {
                      unstable = final;
                      stable = final.stable;
                    })
                  ]
                  ++ (import ./overlay/master.nix attrs);
              };
              stable = import attrs.nixpkgs-stable {
                inherit system config;
                overlays =
                  [
                    (_: _: {
                      unstable = final;
                      master = final.master;
                    })
                  ]
                  ++ (import ./overlay/stable.nix attrs);
              };
            })
          ]
          ++ (import ./overlay attrs);
      };

    nixosModules = {
      lotus-notebook = [
        agenix.nixosModules.age
        ./nixos
        ./nixos/notebook
      ];
      gce-automation = [
        "${nixpkgs}/nixos/modules/virtualisation/google-compute-image.nix"
        ./servers/gce-automation
      ];
    };

    globalConfig = {
      templates = import ./templates attrs;

      nixosConfigurations = builtins.mapAttrs (_: modules: let
        system = flake-utils.lib.system.x86_64-linux;
      in
        nixpkgs.lib.nixosSystem
        {
          inherit system;
          modules =
            modules
            ++ [
              attrs.determinate.nixosModules.default
            ];
          pkgs = pkgsFun system;
          specialArgs = {
            inputs = attrs;
          };
        })
      nixosModules;

      homeConfigurations."lotus@lotus-notebook" = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFun flake-utils.lib.system.x86_64-linux;
        extraSpecialArgs = {
          inputs = attrs;
        };

        modules = [
          agenix.homeManagerModules.age
          ./nix-home
          ./nix-home/notebook.nix
        ];
      };
    };

    perSystemConfig = flake-utils.lib.eachDefaultSystem (system: let
      pkgs = pkgsFun system;
    in {
      legacyPackages = pkgs;

      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        packages = [];
      };

      apps = import ./commands.nix {
        inherit self pkgs;
        homeManagerBin = "${home-manager.packages.${system}.home-manager}/bin/home-manager";
      };
    });
  in
    globalConfig // perSystemConfig;
}
