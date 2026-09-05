{
  lib,
  stdenvNoCC,
  python3,
  git,
  gum,
  treehouse,
  source,
}:
stdenvNoCC.mkDerivation {
  pname = "herdr-treehouse";
  version = "0.1.0";

  src = source;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp LICENSE herdr-plugin.toml open_branch_worktree.py reconcile_worktrees.py "$out/"

    substituteInPlace "$out/herdr-plugin.toml" \
      --replace-fail '["python3",' '["${lib.getExe python3}",'
    substituteInPlace "$out/open_branch_worktree.py" \
      --replace-fail '"git"' '"${lib.getExe git}"' \
      --replace-fail '"gum"' '"${lib.getExe gum}"' \
      --replace-fail '"treehouse"' '"${lib.getExe treehouse}"'
    substituteInPlace "$out/reconcile_worktrees.py" \
      --replace-fail '"treehouse"' '"${lib.getExe treehouse}"'

    runHook postInstall
  '';

  meta = {
    description = "Treehouse integration plugin for Herdr";
    homepage = "https://git.fryuni.dev/Fryuni/herdr-treehouse";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
