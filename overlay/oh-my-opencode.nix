{
  stdenv,
  lib,
  fetchFromGitHub,
  bun,
  autoPatchelfHook,
  glibc,
  gcc-unwrapped,
  cacert,
}: let
  version = "3.3.2";

  src = fetchFromGitHub {
    owner = "code-yeongyu";
    repo = "oh-my-opencode";
    rev = "v${version}";
    hash = "sha256-7m+KubTgeev4fc9loAJyW8KKNOFO3sMiLqpAShTizKk=";
  };

  # Fixed-output derivation to fetch dependencies with network access
  node_modules = stdenv.mkDerivation {
    pname = "oh-my-opencode-deps";
    inherit version src;

    nativeBuildInputs = [bun cacert];

    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    # Bun needs a writable home/cache directory
    HOME = "/build/home";

    installPhase = ''
      runHook preInstall

      mkdir -p $HOME

      # Install dependencies (network access allowed in FOD)
      bun install

      # Copy node_modules to output
      mkdir -p $out
      cp -r node_modules/* $out/

      runHook postInstall
    '';

    # Fixed-output derivation: allows network access but requires hash
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-50ONIFDNkls1VgJ1B0DusCAp0o5WAXSlUwTn526MIjY=";
  };
in
  stdenv.mkDerivation {
    pname = "oh-my-opencode";
    inherit version src;

    nativeBuildInputs = [
      bun
      autoPatchelfHook
    ];

    buildInputs = [
      glibc
      gcc-unwrapped
    ];

    # Bun needs a writable home/cache directory
    HOME = "/build/home";

    dontConfigure = true;
    dontStrip = true;

    buildPhase = ''
      runHook preBuild

      mkdir -p $HOME

      # Link pre-fetched node_modules
      cp -r ${node_modules} node_modules
      chmod -R u+w node_modules

      # Build the standalone binary for linux-x64
      bun build \
        --compile \
        --minify \
        --sourcemap \
        --bytecode \
        --target=bun-linux-x64 \
        src/cli/index.ts \
        --outfile=oh-my-opencode

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp oh-my-opencode $out/bin/oh-my-opencode
      chmod +x $out/bin/oh-my-opencode

      runHook postInstall
    '';

    meta = with lib; {
      description = "The Best Agent Harness - Batteries-Included Agent that codes like you";
      homepage = "https://github.com/code-yeongyu/oh-my-opencode";
      license = licenses.unfree; # SUL-1.0
      platforms = ["x86_64-linux"];
      mainProgram = "oh-my-opencode";
    };
  }
