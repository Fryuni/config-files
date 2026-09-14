{
  lib,
  stdenv,
  fetchurl,
  fetchNpmDeps,
  npmHooks,
  nodejs_26,
  makeWrapper,
  autoPatchelfHook,
  versionCheckHook,
}: let
  # Update binaries and the npm toolchain together with update-vite-plus.py.
  version = "0.3.2";
  releases = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-cA+3ZEBR8DvdRkZpSYIcd6o70l2DPgJ/rACpDTc8q2k=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-DO+YgDRShvQx7XSavbnkldykM1fB8sjbFslhqeF8qQs=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-f4SBYB+Gn3MG0xmjVE1M++iaVwfZNLP7Ud5CJUhsNCE=";
    };
  };
  release = releases.${stdenv.hostPlatform.system} or (throw "Unsupported Vite+ system: ${stdenv.hostPlatform.system}");
  cli = fetchurl {
    url = "https://github.com/voidzero-dev/vite-plus/releases/download/v${version}/vp-${release.target}.tar.gz";
    inherit (release) hash;
  };
in
  stdenv.mkDerivation {
    pname = "vite-plus";
    inherit version;
    src = ./vite-plus;

    # The npm layout and native-binding fixups follow nixpkgs PR #533925,
    # which fixes the missing JS toolchain in #500492:
    # https://github.com/NixOS/nixpkgs/pull/533925
    # https://github.com/NixOS/nixpkgs/pull/500492
    # Use upstream's binary to retain fspy task tracing, stubbed in those PRs.
    npmDeps = fetchNpmDeps {
      name = "vite-plus-${version}-npm-deps";
      src = ./vite-plus;
      fetcherVersion = 1;
      hash = "sha256-lmOMSzRHwLTOYLs5BNCkHsAFdZ1SP4uM+E8Yb80L37A=";
    };

    nativeBuildInputs =
      [
        npmHooks.npmConfigHook
        nodejs_26
        makeWrapper
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [stdenv.cc.cc.lib];
    npmRebuildFlags = ["--ignore-scripts"];
    dontConfigure = true;
    dontStrip = true;

    buildPhase = ''
      runHook preBuild

      # Copies of store templates otherwise inherit read-only permissions.
      substituteInPlace node_modules/vite-plus/dist/create/bin.js \
        --replace-fail \
          'else fs.copyFileSync(src, dest);' \
          'else { fs.copyFileSync(src, dest); fs.chmodSync(dest, 0o644); }'

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      tar xf ${cli} -C $out/bin
      mv node_modules $out/node_modules
      rm -f $out/node_modules/.package-lock.json

      # Without the marker, even --help runs upstream's installer and edits
      # the user's shell setup. Nix owns installation and upgrades here.
      touch $out/bin/.vp-setup-complete

      # Preserve project-selected Node versions; provide Nix Node as fallback.
      # Managed runtimes are supported by the hosts' existing nix-ld setup.
      wrapProgram $out/bin/vp \
        --suffix PATH : ${lib.makeBinPath [nodejs_26]}

      runHook postInstall
    '';

    nativeInstallCheckInputs = [versionCheckHook];
    doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
    preInstallCheck = ''
      # Keep checks offline and isolate any runtime state from the user.
      export VP_HOME="$TMPDIR/vite-plus-check"
      $out/bin/vp env off node
      $out/bin/vp create --help > /dev/null
      test ! -e "$VP_HOME/bin"
    '';

    meta = {
      description = "Unified toolchain and entry point for web development";
      homepage = "https://viteplus.dev";
      changelog = "https://github.com/voidzero-dev/vite-plus/releases/tag/v${version}";
      license = lib.licenses.mit;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "vp";
      platforms = builtins.attrNames releases;
    };
  }
