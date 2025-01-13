{
  description = "Fryuni's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-master.url = "github:Fryuni/nixpkgs/master";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    systems.url = "github:nix-systems/default";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.flake-utils.follows = "flake-utils";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.systems.follows = "systems";
    };
    charm = {
      url = "github:charmbracelet/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    polymc = {
      url = "github:Fryuni/PolyMC/develop";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.flake-compat.follows = "flake-compat";
    };
    direnv = {
      url = "github:direnv/direnv";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.gomod2nix.follows = "gomod2nix";
      inputs.systems.follows = "systems";
    };
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.flake-utils.follows = "flake-utils";
      inputs.flake-compat.follows = "flake-compat";
    };
  };

  outputs = {
    self,
    nixpkgs,
    fenix,
    charm,
    # nixos-hardware,
    home-manager,
    flake-utils,
    agenix,
    nix-alien,
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
            fenix.overlays.default
            agenix.overlays.default
            nix-alien.overlays.default
            (import "${charm}/overlay.nix")
          ]
          ++ (import ./overlay attrs)
          ++ [
            attrs.polymc.overlay
          ];
      };

    nixosModules = {
      notebook = [
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

      nixosConfigurations = builtins.mapAttrs (_: modules:
        nixpkgs.lib.nixosSystem rec {
          inherit modules;
          system = flake-utils.lib.system.x86_64-linux;
          pkgs = pkgsFun system;
          specialArgs = {
            inputs = attrs;
          };
        })
      nixosModules;

      homeConfigurations.notebook = home-manager.lib.homeManagerConfiguration {
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

      apps = import ./commands.nix {
        inherit self pkgs;
        homeManagerBin = "${home-manager.packages.${system}.home-manager}/bin/home-manager";
      };
    });
  in
    globalConfig // perSystemConfig;
}
