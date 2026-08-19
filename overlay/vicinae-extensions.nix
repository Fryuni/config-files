attrs: final: pkgs: let
  inherit (pkgs.stdenv.hostPlatform) system;

  mkVicinaeExtension = attrs.vicinae.lib.${system}.mkVicinaeExtension;
  vicinaeExtensionsSource = attrs.vicinae-extensions.outPath;

  mkOfficialExtension = name:
    mkVicinaeExtension {
      pname = "vicinae-extension-${name}";
      version = "0";
      src = "${vicinaeExtensionsSource}/extensions/${name}";
      postPatch = ''
        substituteInPlace tsconfig.json --replace "../../" "${vicinaeExtensionsSource}/"
      '';
    };
in {
  # Vicinae extensions from the official store, built via Nix.
  # Available extension names are the directories under the upstream extensions/
  # source tree.
  #
  # The upstream extensions flake currently calls the builder through
  # vicinae.packages.${system}.mkVicinaeExtension, but current Vicinae exposes
  # it under vicinae.lib.${system}.mkVicinaeExtension. Build the selected
  # official extension sources directly until upstream's flake catches up.
  vicinae-official-extensions = builtins.map mkOfficialExtension [
    "aria2-manager"
    "dashboard-icons"
    "it-tools"
    "nerdfont-search"
    "nix"
    "port-killer"
  ];
}
