{
  stdenvNoCC,
  fetchurl,
}: let
  pname = "cpa-manager-plus";
  version = "1.12.1";
in
  stdenvNoCC.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/seakee/CPA-Manager-Plus/releases/download/v${version}/${pname}_v${version}_linux_amd64.tar.gz";
      hash = "sha256-xss6iWamAYFowaAo/Mre0EJeX9j+dCxFXE+jeIbJGNw=";
    };

    sourceRoot = "${pname}_v${version}_linux_amd64";
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      install -Dm755 cpa-manager-plus $out/bin/cpa-manager-plus
      install -Dm755 cpa-manager-plusctl $out/bin/cpa-manager-plusctl
    '';

    meta.mainProgram = "cpa-manager-plus";
  }
