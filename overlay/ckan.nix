{
  stdenv,
  fetchurl,
  mono,
  dpkg,
  glibc,
  gcc-unwrapped,
  autoPatchelfHook,
}:
stdenv.mkDerivation rec {
  pname = "ksp-ckan";
  version = "1.31.2";

  src = fetchurl {
    url = "https://github.com/KSP-CKAN/CKAN/releases/download/v${version}/ckan_${version}_all.deb";
    sha256 = "sha256-vysUBMy4+ymyivE2XvrC6xxLv5zn9eKwYaJETdb5StQ=";
  };

  system = "x86_64-linux";

  # Required for compilation
  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    mono
  ];

  # Required at runtime
  buildInputs = [
    glibc
    gcc-unwrapped
    mono
  ];

  unpackPhase = "true";

  # Extract and copy executable in $out/bin
  installPhase = ''
    mkdir -p $out
    dpkg -x $src $out
    mkdir -p $out/bin
    cp -av $out/usr/bin/ckan $out/bin/ksp-ckan
    rm -rf $out/usr/bin
  '';

  # meta =  {
  #   description = "The Comprehensive Kerbal Archive Network";
  #   homepage = "https://github.com/KSP-CKAN/CKAN";
  #   license = licenses.mit;
  #   maintainers = with stdenv.lib.maintainers; [ ];
  #   platforms = [ "x86_64-linux" ];
  # };
}
