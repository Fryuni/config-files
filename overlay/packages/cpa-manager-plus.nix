{
  stdenvNoCC,
  fetchurl,
}: let
  pname = "cpa-manager-plus";
  version = "1.13.1";
in
  stdenvNoCC.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/seakee/CPA-Manager-Plus/releases/download/v${version}/${pname}_v${version}_linux_amd64.tar.gz";
      hash = "sha256-Gsj2wo+0On3YuqGW5iZ2I6SHt+WQjNjBQ4jFpRvI2NM=";
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
