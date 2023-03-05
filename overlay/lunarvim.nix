pkgs: let
  inherit (pkgs) stdenv;

  lunarvim-src = pkgs.fetchFromGitHub {
    owner = "lunarvim";
    repo = "lunarvim";
    rev = "release-1.2/neovim-0.8";
    sha256 = "sha256-HHfqFi6SHmbKjvmkI5uDvDccN4uyKsjSVEdaZJ2s7xc=";
  };

  lunarvim-shim = pkgs.writeShellScriptBin "lvim" ''
    XDG_DATA_HOME="''${XDG_DATA_HOME:-"$HOME/.local/share"}"
    XDG_CACHE_HOME="''${XDG_CACHE_HOME:-"$HOME/.cache"}"
    XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-"$HOME/.config"}"

    export LUNARVIM_RUNTIME_DIR="''${LUNARVIM_RUNTIME_DIR:-"''$XDG_DATA_HOME/lunarvim"}"
    export LUNARVIM_CONFIG_DIR="''${LUNARVIM_CONFIG_DIR:-"''$XDG_CONFIG_HOME/lvim"}"
    export LUNARVIM_CACHE_DIR="''${LUNARVIM_CACHE_DIR:-"''$XDG_CACHE_HOME/lvim"}"

    export LUNARVIM_BASE_DIR="''${LUNARVIM_BASE_DIR:-"''${LUNARVIM_RUNTIME_DIR}/lvim"}"

    mkdir -p "$LUNARVIM_CACHE_DIR" "$LUNARVIM_CONFIG_DIR" "$LUNARVIM_RUNTIME_DIR"

    if [ ! -d "$LUNARVIM_BASE_DIR" ]; then
      cp -R "${lunarvim-src}" "$LUNARVIM_BASE_DIR"
    fi

    [ ! -f "$LUNARVIM_CONFIG_DIR/config.lua" ] \
      && cp "$LUNARVIM_BASE_DIR/utils/installer/config.example.lua" "$LUNARVIM_CONFIG_DIR/config.lua"

    env | rg 'LUNAR'

    exec -a lvim ${pkgs.neovim}/bin/nvim -u "$LUNARVIM_BASE_DIR/init.lua" "$@"
  '';

  lunarvim = stdenv.mkDerivation {
    pname = "lunarvim";
    version = "1.2";
    src = lunarvim-src;

    nativeBuildInputs = with pkgs; [makeWrapper];
    buildInputs = with pkgs; [git neovim];

    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      runHook preInstall
      echo "Installing lunarvim on $out"

      runHook postInstall
    '';
  };
in {
  inherit lunarvim-src;
  lunarvim = lunarvim-shim;
}
