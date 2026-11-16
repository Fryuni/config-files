{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  makeWrapper,
  nodejs_22,
}:
buildNpmPackage {
  # better-sqlite3 12 aborts during environment teardown on Node 24; upstream targets Node 22.
  nodejs = nodejs_22;

  pname = "novelmaker";
  version = "0-unstable-2026-11-13";

  src = fetchFromGitHub {
    owner = "maniesoft";
    repo = "Novelmaker-public";
    rev = "9e8e78589c0bbcabbc41891197033214a7bbeb6a";
    hash = "sha256-kHabXo4JPwMbNyN8gfmyROQco+BlFCmtbfa3brWW0Ow=";
  };

  npmDepsHash = "sha256-oZb4pTQNj10wwSlOJ2FvHHANoeoDpNThdH6mRHvl8Ck=";

  nativeBuildInputs = [makeWrapper];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    npm test
    runHook postCheck
  '';

  # Upstream runs the TypeScript server straight from the checkout through tsx,
  # and serves the built interface from web/dist next to it.
  installPhase = ''
    runHook preInstall

    # The interface is bundled into web/dist, so its libraries are not needed at runtime.
    npm pkg set --json workspaces='["shared","server"]'
    npm prune --omit=dev
    # node-gyp's intermediates reference the Node.js sources and the npm cache.
    find node_modules/better-sqlite3/build -type f ! -path '*/build/Release/better_sqlite3.node' -delete

    mkdir -p $out/lib/novelmaker/web
    cp -r package.json node_modules server shared $out/lib/novelmaker/
    cp -r web/dist $out/lib/novelmaker/web/

    # The default data folder sits inside the program folder, which is read-only here.
    makeWrapper ${lib.getExe nodejs_22} $out/bin/novelmaker \
      --add-flags "--import $out/lib/novelmaker/node_modules/tsx/dist/loader.mjs" \
      --add-flags "$out/lib/novelmaker/server/src/index.ts" \
      --run 'export NOVELMAKER_DATA="''${NOVELMAKER_DATA:-''${XDG_DATA_HOME:-$HOME/.local/share}/novelmaker}"'

    runHook postInstall
  '';

  meta = {
    description = "Local writing app for novels with AI help built into the manuscript";
    homepage = "https://github.com/maniesoft/Novelmaker-public";
    license = lib.licenses.agpl3Only;
    mainProgram = "novelmaker";
    platforms = lib.platforms.linux;
  };
}
