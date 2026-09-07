{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.services.nixStoreCache;
  determinateEnabled = config.determinate.enable or false;
  runtimeDirectory = "/run/nix-store-cache";
  daemonNetrc =
    if determinateEnabled
    then "${runtimeDirectory}/netrc"
    else cfg.netrcFile;
  prepareNetrc = pkgs.writeShellScript "prepare-nix-store-cache-netrc" ''
    set -eu
    umask 077
    ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.netrcFile} > ${runtimeDirectory}/netrc.tmp
    printf '\n' >> ${runtimeDirectory}/netrc.tmp
    if [ -f /nix/var/determinate/netrc ]; then
      ${pkgs.coreutils}/bin/cat /nix/var/determinate/netrc >> ${runtimeDirectory}/netrc.tmp
    fi
    ${pkgs.coreutils}/bin/mv ${runtimeDirectory}/netrc.tmp ${runtimeDirectory}/netrc
  '';

  uploadHook = pkgs.writeShellScript "upload-nix-store-paths-to-cubby" ''
    if [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ]; then
      export NIX_REMOTE=local
    fi

    if ! ${config.nix.package}/bin/nix copy \
      --option netrc-file ${lib.escapeShellArg daemonNetrc} \
      --to ${lib.escapeShellArg cfg.endpoint} \
      --no-recursive \
      $OUT_PATHS; then
      echo "warning: failed to upload build outputs to the remote Nix store cache" >&2
    fi
    exit 0
  '';
in {
  options.services.nixStoreCache = {
    enable = mkEnableOption "the authenticated remote Cubby Nix store cache";

    endpoint = mkOption {
      type = types.str;
      example = "https://cache.example.net/nix";
      description = "Cubby HTTPS cache base URL. User information, queries, fragments, and whitespace are not allowed. HTTP is allowed only on localhost for testing.";
    };

    netrcFile = mkOption {
      type = types.str;
      example = "/run/agenix/nix-store-cache-netrc";
      description = "Absolute runtime path to a root-readable netrc file containing the cache hostname, an empty login, and the Cubby token as password.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.netrcFile;
        message = "services.nixStoreCache.netrcFile must be an absolute path";
      }
      {
        assertion = builtins.match "(https://[^/@:?#[:space:][:cntrl:]]+|http://(localhost|127\\.0\\.0\\.1))(:[0-9]+)?(/[^?#[:space:][:cntrl:]]*)?" cfg.endpoint != null;
        message = "services.nixStoreCache.endpoint must be an HTTPS URL without credentials, queries, fragments, or whitespace (HTTP is allowed only on localhost)";
      }
    ];

    nix.settings = {
      fallback = true;
      substituters = lib.mkBefore [cfg.endpoint];
      netrc-file = cfg.netrcFile;
      post-build-hook = uploadHook;
    };

    systemd.services.nix-daemon = {
      unitConfig.RequiresMountsFor = [cfg.netrcFile];
      # Determinate writes netrc-file after nix.custom.conf. Environment settings
      # take precedence without publishing the cache token in its shared netrc.
      environment.NIX_CONFIG = lib.mkIf determinateEnabled "netrc-file = ${daemonNetrc}";
      serviceConfig = lib.mkIf determinateEnabled {
        RuntimeDirectory = "nix-store-cache";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = [prepareNetrc];
      };
    };
  };
}
