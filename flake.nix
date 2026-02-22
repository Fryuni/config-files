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
    flakehub = {
      url = "https://flakehub.com/f/DeterminateSystems/fh/*";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
    };

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
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.flake-compat.follows = "flake-compat";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    home-manager,
    flake-utils,
    agenix,
    ...
  } @ attrs: let
    nixpkgsConfig = {
      allowUnfree = true;
      permittedInsecurePackages = [
      ];
      # https://github.com/NixOS/nixpkgs/pull/258447
      # https://discourse.nixos.org/t/your-system-configures-nixpkgs-with-an-externally-created-instance/33802
      pulseaudio = true;

      doCheckByDefault = false;
    };

    # Overlay providing pkgs.master and pkgs.stable channel access.
    # Detects cross-compilation from stdenv and adjusts channel imports.
    channelOverlays = final: _: let
      isCross = final.stdenv.buildPlatform.system != final.stdenv.hostPlatform.system;
      channelArgs =
        {config = nixpkgsConfig;}
        // (
          if isCross
          then {
            localSystem = final.stdenv.buildPlatform.system;
            crossSystem = final.stdenv.hostPlatform.system;
          }
          else {
            inherit (final.stdenv.hostPlatform) system;
          }
        );
    in {
      master = import attrs.nixpkgs-master (channelArgs
        // {
          overlays =
            [
              (_: _: {
                unstable = final;
                inherit (final) stable;
              })
            ]
            ++ (import ./overlay/master.nix attrs);
        });
      stable = import attrs.nixpkgs-stable (channelArgs
        // {
          overlays =
            [
              (_: _: {
                unstable = final;
                inherit (final) master;
              })
            ]
            ++ (import ./overlay/stable.nix attrs);
        });
    };

    pkgsFun = system:
      import nixpkgs {
        inherit system;
        config = nixpkgsConfig;

        overlays =
          [channelOverlays]
          ++ (import ./overlay attrs);
      };

    nixosModules = [
      {
        system = flake-utils.lib.system.x86_64-linux;
        boxes = {
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
      }
      {
        system = flake-utils.lib.system.aarch64-linux;

        boxes = {
          lotus-rpi3 = [
            home-manager.nixosModules.home-manager
            ./nixos/rpi3
          ];
        };
      }
    ];

    globalConfig = {
      templates = import ./templates attrs;

      nixosConfigurations =
        builtins.foldl' (
          acc: entry: let
            isCross =
              builtins ? currentSystem
              && entry.system != builtins.currentSystem;
          in
            acc
            // builtins.mapAttrs (_: modules:
              nixpkgs.lib.nixosSystem (
                {
                  modules =
                    modules
                    ++ nixpkgs.lib.optionals (!isCross) [
                      attrs.determinate.nixosModules.default
                    ]
                    ++ nixpkgs.lib.optionals isCross [
                      {
                        nixpkgs.hostPlatform = entry.system;
                        nixpkgs.buildPlatform = builtins.currentSystem;
                        nixpkgs.config = nixpkgsConfig;
                        nixpkgs.overlays = [channelOverlays];
                      }
                    ];
                  specialArgs = {
                    inputs = attrs;
                  };
                }
                // nixpkgs.lib.optionalAttrs (!isCross) {
                  inherit (entry) system;
                  pkgs = pkgsFun entry.system;
                }
              ))
            entry.boxes
        ) {}
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
