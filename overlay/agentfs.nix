final: pkgs: let
  inherit (final.fenix.complete) toolchain;
  rustPlatform = final.makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };
in {
  agentfs = rustPlatform.buildRustPackage {
    pname = "agentfs";
    version = "0.6.2";

    src = pkgs.fetchFromGitHub {
      owner = "tursodatabase";
      repo = "agentfs";
      rev = "v0.6.2";
      hash = "sha256-nnbC7JBAZN+gtYURnhkziNW0+6LYL/2HvA+HU3jw9hE=";
    };

    buildAndTestSubdir = "cli";

    cargoLock = {
      lockFile = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/tursodatabase/agentfs/v0.6.2/cli/Cargo.lock";
        hash = "sha256-j5lN6bvAi5GLVRpcymy7JSuYLLveENbpR/y/hDiZzhY=";
      };
      outputHashes = {
        "reverie-0.1.0" = "sha256-Cx/i0AS3I8CK1wOr0dcQFjlxycgttXDS85qjon2oQZw=";
      };
    };

    postUnpack = ''
      cp source/cli/Cargo.lock source/Cargo.lock
    '';

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      pkg-config
      git
    ];

    buildInputs = with pkgs; [
      openssl
      libunwind
      xz # liblzma
      libgcc
    ];

    # build.rs links liblzma and libgcc_s for sandbox/libunwind-ptrace
    LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [xz libgcc]);

    doCheck = false;

    meta = {
      description = "The filesystem for AI agents";
      homepage = "https://github.com/tursodatabase/agentfs";
      mainProgram = "agentfs";
    };
  };
}
