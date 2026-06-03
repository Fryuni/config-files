final: pkgs: let
  honchoVersion = "3.0.7";
  honchoSrc = pkgs.fetchFromGitHub {
    owner = "plastic-labs";
    repo = "honcho";
    rev = "v${honchoVersion}";
    hash = "sha256-g/uZgSqCOzNiGSAQugEkPwz2+Wt6DPBiMNCRjzmA8sc=";
  };
in {
  honcho-ai = pkgs.python313Packages.buildPythonPackage rec {
    pname = "honcho-ai";
    version = "2.1.2";
    pyproject = true;

    src = honchoSrc;
    sourceRoot = "${src.name}/sdks/python";

    build-system = with pkgs.python313Packages; [
      setuptools
      wheel
    ];

    dependencies = with pkgs.python313Packages; [
      httpx
      pydantic
      typing-extensions
    ];

    pythonImportsCheck = ["honcho"];

    meta = {
      description = "Python SDK for Honcho";
      homepage = "https://github.com/plastic-labs/honcho";
      license = pkgs.lib.licenses.asl20;
      maintainers = with pkgs.lib.maintainers; [fryuni];
    };
  };

  honcho-cli = pkgs.python313Packages.buildPythonApplication rec {
    pname = "honcho-cli";
    version = "0.1.0";
    pyproject = true;

    src = honchoSrc;
    sourceRoot = "${src.name}/honcho-cli";

    build-system = with pkgs.python313Packages; [
      hatchling
    ];

    dependencies = with pkgs.python313Packages; [
      final.honcho-ai
      httpx
      rich
      typer
    ];

    pythonImportsCheck = ["honcho_cli"];

    meta = {
      description = "Terminal CLI for Honcho";
      homepage = "https://github.com/plastic-labs/honcho";
      license = pkgs.lib.licenses.mit;
      mainProgram = "honcho";
      maintainers = with pkgs.lib.maintainers; [fryuni];
    };
  };

  honcho = final.callPackage ({
    lib,
    cacert,
    stdenvNoCC,
    fetchurl,
    makeWrapper,
    python313Packages,
  }: let
    tiktokenCache = stdenvNoCC.mkDerivation {
      name = "honcho-tiktoken-cache";

      dontUnpack = true;

      cl100kBase = fetchurl {
        url = "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken";
        hash = "sha256-Ijkht27pm96ZW3/3OFE+7xAPtR0YyTWXoRO8/+hlsqc=";
      };

      o200kBase = fetchurl {
        url = "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken";
        hash = "sha256-RGqVOMtsNI41FhINfAiwn1fDZJXirP/+WaW/iwz7Gi0=";
      };

      installPhase = ''
        runHook preInstall

        mkdir -p $out
        cp $cl100kBase $out/9b5ad71b2ce5302211f9c61530b329a4922fc6a4
        cp $o200kBase $out/fb374d419588a4632f3f557e76b4b70aebbca790

        runHook postInstall
      '';
    };

    pythonEnv = python313Packages.python.withPackages (ps:
      with ps; [
        aiohttp
        alembic
        anthropic
        cashews
        cloudevents
        email-validator
        fastapi
        fastapi-pagination
        google-genai
        greenlet
        httptools
        httpx
        json-repair
        lancedb
        langfuse
        nanoid
        openai
        pdfplumber
        pgvector
        prometheus-client
        psycopg
        pyarrow
        pydantic
        pydantic-settings
        pyjwt
        python-dotenv
        python-multipart
        redis
        rich
        scikit-learn
        sentry-sdk
        sqlalchemy
        tenacity
        tiktoken
        typing-extensions
        uvicorn
        uvloop
        watchfiles
        websockets
      ]);
  in
    stdenvNoCC.mkDerivation {
      pname = "honcho";
      version = honchoVersion;

      src = honchoSrc;

      nativeBuildInputs = [makeWrapper];

      dontBuild = true;

      installPhase = ''
        runHook preInstall

        mkdir -p $out/share/honcho $out/bin
        cp -R \
          alembic.ini \
          config.toml.example \
          migrations \
          scripts \
          src \
          $out/share/honcho/

        patchShebangs $out/share/honcho/scripts

        makeWrapper ${pythonEnv}/bin/python $out/bin/honcho-api \
          --chdir $out/share/honcho \
          --set-default PYTHONDONTWRITEBYTECODE 1 \
          --set-default PYTHONUNBUFFERED 1 \
          --set-default REQUESTS_CA_BUNDLE ${cacert}/etc/ssl/certs/ca-bundle.crt \
          --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt \
          --set-default TIKTOKEN_CACHE_DIR ${tiktokenCache} \
          --prefix PYTHONPATH : $out/share/honcho \
          --add-flags "-m uvicorn src.main:app"

        makeWrapper ${pythonEnv}/bin/python $out/bin/honcho-deriver \
          --chdir $out/share/honcho \
          --set-default PYTHONDONTWRITEBYTECODE 1 \
          --set-default PYTHONUNBUFFERED 1 \
          --set-default REQUESTS_CA_BUNDLE ${cacert}/etc/ssl/certs/ca-bundle.crt \
          --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt \
          --set-default TIKTOKEN_CACHE_DIR ${tiktokenCache} \
          --prefix PYTHONPATH : $out/share/honcho \
          --add-flags "-m src.deriver"

        makeWrapper ${pythonEnv}/bin/python $out/bin/honcho-migrate-db \
          --chdir $out/share/honcho \
          --set-default PYTHONDONTWRITEBYTECODE 1 \
          --set-default PYTHONUNBUFFERED 1 \
          --set-default REQUESTS_CA_BUNDLE ${cacert}/etc/ssl/certs/ca-bundle.crt \
          --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt \
          --set-default TIKTOKEN_CACHE_DIR ${tiktokenCache} \
          --prefix PYTHONPATH : $out/share/honcho \
          --add-flags "$out/share/honcho/scripts/provision_db.py"

        makeWrapper ${pythonEnv}/bin/python $out/bin/honcho-configure-embeddings \
          --chdir $out/share/honcho \
          --set-default PYTHONDONTWRITEBYTECODE 1 \
          --set-default PYTHONUNBUFFERED 1 \
          --set-default REQUESTS_CA_BUNDLE ${cacert}/etc/ssl/certs/ca-bundle.crt \
          --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt \
          --set-default TIKTOKEN_CACHE_DIR ${tiktokenCache} \
          --prefix PYTHONPATH : $out/share/honcho \
          --add-flags "$out/share/honcho/scripts/configure_embeddings.py"

        runHook postInstall
      '';

      doInstallCheck = true;

      installCheckPhase = ''
        runHook preInstallCheck

        export PYTHONPATH=$out/share/honcho
        export DB_CONNECTION_URI=postgresql+psycopg:///honcho?host=/run/postgresql
        export LLM_OPENAI_API_KEY=test-key
        export AUTH_USE_AUTH=false
        export REQUESTS_CA_BUNDLE=${cacert}/etc/ssl/certs/ca-bundle.crt
        export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
        export TIKTOKEN_CACHE_DIR=${tiktokenCache}
        cd $out/share/honcho
        ${pythonEnv}/bin/python -c 'import src.main; import src.deriver.queue_manager; import scripts.configure_embeddings'

        runHook postInstallCheck
      '';

      passthru = {
        python = pythonEnv;
      };

      meta = {
        description = "Honcho self-hosted API server and background deriver";
        homepage = "https://honcho.dev";
        license = lib.licenses.agpl3Only;
        mainProgram = "honcho-api";
        maintainers = with lib.maintainers; [fryuni];
        platforms = lib.platforms.linux;
      };
    }) {};
}
