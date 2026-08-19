{
stdenvNoCC,
fetchurl,
nix-update-script,
}: let
    pname = "cpa-manager-plus";
    version = "1.11.12";
  in
    stdenvNoCC.mkDerivation {
      inherit pname version;

      src = fetchurl {
        url = "https://github.com/seakee/CPA-Manager-Plus/releases/download/v${version}/${pname}_v${version}_linux_amd64.tar.gz";
        hash = "sha256-z2KHzZoDO68XwIb+5emVyiuse68Cl1qyYG1meIbfkTI=";
      };

      sourceRoot = "${pname}_v${version}_linux_amd64";
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        install -Dm755 cpa-manager-plus $out/bin/cpa-manager-plus
        install -Dm755 cpa-manager-plusctl $out/bin/cpa-manager-plusctl
      '';

      passthru.updateScript = nix-update-script {};

      meta.mainProgram = "cpa-manager-plus";
}
