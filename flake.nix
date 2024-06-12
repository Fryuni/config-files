{
  description = "Fryuni's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-master.url = "github:Fryuni/nixpkgs/master";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    charm = {
      url = "github:charmbracelet/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    polymc = {
      url = "github:Fryuni/PolyMC/develop";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    direnv = {
      url = "github:direnv/direnv";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    nix-alien.url = "github:thiagokokada/nix-alien";
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

    globalConfig = {
      templates = import ./templates attrs;

      nixosConfigurations.notebook = nixpkgs.lib.nixosSystem rec {
        system = flake-utils.lib.system.x86_64-linux;
        pkgs = pkgsFun system;
        specialArgs = {
          inputs = attrs;
        };

        modules = [
          agenix.nixosModules.age
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
