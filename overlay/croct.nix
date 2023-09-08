pkgs: prev: {
  croct-php = prev.php81.withExtensions ({
    enabled,
    all,
  }:
    with all;
      enabled
      ++ [
        mbstring
        filter

        openssl
        curl
        pdo
        pdo_pgsql
        pdo_sqlite
        redis
        bcmath
        intl
        swoole
        dom
        simplexml
        xmlwriter
        tokenizer

        xdebug
        pcov
        # (pkgs.php81.buildPecl rec {
        #   pname = "decimal";
        #   version = "v1.4.0";
        #
        #   LIBMPDEC_DIR = "${pkgs.mpdecimal.dev}/include";
        #
        #   src = pkgs.fetchFromGitHub {
        #     owner = "php-decimal";
        #     repo = "ext-decimal";
        #     rev = version;
        #     sha256 = "sha256-1xP6DqRWK5fFaPNwXXzTjZVkFzxmG9Uzy8qxrYjYvbA=";
        #   };
        # })
      ]);

  croct-php-env = prev.stdenvNoLibs.mkDerivation {
    pname = "croct-php-env";
    version = "8.1";
    # buildInputs = [
    #   croct-php-pkg
    #   croct-php-pkg.packages.composer
    # ];

    dontUnpack = true;
    dontBuild = true;

    NIX_DEBUG = 10;
    installPhase = ''
      mkdir -p $out/bin
      ln -s "${pkgs.croct-php}/bin/php" "$out/bin/php"
      ln -s "${pkgs.croct-php.packages.composer}/bin/composer" $out/bin/composer
    '';
  };
}
