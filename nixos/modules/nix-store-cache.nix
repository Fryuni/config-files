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
  daemonNetrc = "${runtimeDirectory}/netrc";
  prepareNetrc = pkgs.writeShellScript "prepare-nix-store-cache-netrc" ''
    set -eu
    umask 077
    ${pkgs.python3}/bin/python3 -c '
    import sys
    from pathlib import Path
    from urllib.parse import urlsplit

    token = Path(sys.argv[1]).read_text().rstrip("\n")
    if not token or any(c in token for c in "\r\n\0"):
        sys.exit("Cache token must be a nonempty single line")
    password = token.replace("\\", "\\\\").replace("\"", "\\\"")
    print("machine " + urlsplit(sys.argv[2]).hostname)
    print("login \"\"")
    print("password \"" + password + "\"")
    ' ${lib.escapeShellArg cfg.tokenFile} ${lib.escapeShellArg cfg.endpoint} > ${runtimeDirectory}/netrc.tmp
    ${lib.optionalString determinateEnabled ''
      if [ -f /nix/var/determinate/netrc ]; then
        ${pkgs.coreutils}/bin/cat /nix/var/determinate/netrc >> ${runtimeDirectory}/netrc.tmp
      fi
    ''}
    ${pkgs.coreutils}/bin/mv ${runtimeDirectory}/netrc.tmp ${runtimeDirectory}/netrc
  '';

  queueDirectory = "/nix/var/nix/gcroots/nix-store-cache";
  uploadHook = pkgs.writeShellScript "enqueue-nix-store-paths" ''
    set -eu
    umask 077
    ${pkgs.coreutils}/bin/mkdir -p ${queueDirectory}
    for path in $OUT_PATHS; do
      # Direct GC roots retain closures until upload succeeds or the entry expires.
      # Repeated builds coalesce into the same queue entry.
      ${pkgs.coreutils}/bin/ln -sT "$path" "${queueDirectory}/''${path##*/}" 2>/dev/null \
        || test -L "${queueDirectory}/''${path##*/}"
    done
  '';

  uploadPath = pkgs.writeShellScript "upload-nix-store-cache-path" ''
    set -eu
    # The expiration service may remove an entry after the queue scan.
    path="$(${pkgs.coreutils}/bin/readlink "$1")" || exit 0
    if ${pkgs.cachix}/bin/cachix --host ${lib.escapeShellArg cfg.endpoint} push main \
      "$path"; then
      ${pkgs.coreutils}/bin/rm -f "$1"
    else
      echo "warning: upload failed for $path; retaining GC root for retry" >&2
    fi
    # Failed uploads must not prevent xargs from draining the remaining queue.
    exit 0
  '';

  uploadQueue = pkgs.writeShellScript "drain-nix-store-cache-queue" ''
    set -eu
    export NIX_REMOTE=local
    # Read the write token at runtime; never embed credentials in the Nix store.
    CACHIX_AUTH_TOKEN="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.tokenFile})"
    export CACHIX_AUTH_TOKEN
    # Serialize service/manual invocations, not enqueue operations.
    exec 9>${queueDirectory}/.lock
    ${pkgs.util-linux}/bin/flock -n 9
    while true; do
      ${pkgs.findutils}/bin/find ${queueDirectory} -maxdepth 1 -type l -print0 \
        | ${pkgs.findutils}/bin/xargs -0 -r -n 1 -P ${toString cfg.uploadConcurrency} ${uploadPath}
      ${pkgs.coreutils}/bin/sleep 5
    done
  '';

  expireQueue = pkgs.writeShellScript "expire-nix-store-cache-queue" ''
    set -eu
    if [ -d ${queueDirectory} ]; then
      # Inspect symlink mtime, not target timestamps or access times from retries.
      ${pkgs.findutils}/bin/find ${queueDirectory} -ignore_readdir_race -maxdepth 1 \
        -type l ! -newermt '${toString cfg.maxQueueAgeSeconds} seconds ago' \
        -delete -printf 'Expired cache queue entry: %f\n'
    fi
  '';
in {
  options.services.nixStoreCache = {
    enable = mkEnableOption "the authenticated remote Cubby Nix store cache";

    endpoint = mkOption {
      type = types.str;
      example = "https://cache.example.net/nix";
      description = "Cubby HTTPS cache base URL. User information, queries, fragments, and whitespace are not allowed. HTTP is allowed only on localhost for testing.";
    };

    tokenFile = mkOption {
      type = types.str;
      example = "/run/agenix/nix-store-cache-token";
      description = "Absolute runtime path to a root-readable file containing only the Cubby write token, optionally followed by a newline. Used for Cachix uploads and runtime netrc generation.";
    };

    uploadConcurrency = mkOption {
      type = types.ints.positive;
      default = 1;
      description = "Maximum concurrent Cachix upload processes. Each process may use multiple HTTP connections for multipart uploads. Failed uploads remain queued and are retried after each drain pass and a five-second pause.";
    };

    maxQueueAgeSeconds = mkOption {
      type = types.ints.positive;
      default = 7 * 24 * 60 * 60;
      description = "Maximum queue entry age in seconds. An independent hourly cleanup removes expired GC roots, even if uploads are stalled. Expired outputs are no longer guaranteed to reach the cache; store paths are left for normal garbage collection.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.tokenFile;
        message = "services.nixStoreCache.tokenFile must be an absolute path";
      }
      {
        assertion = builtins.match "(https://[^/@:?#[:space:][:cntrl:]]+|http://(localhost|127\\.0\\.0\\.1))(:[0-9]+)?(/[^?#[:space:][:cntrl:]]*)?" cfg.endpoint != null;
        message = "services.nixStoreCache.endpoint must be an HTTPS URL without credentials, queries, fragments, or whitespace (HTTP is allowed only on localhost)";
      }
    ];

    nix.settings = {
      fallback = true;
      substituters = lib.mkBefore [cfg.endpoint];
      netrc-file = daemonNetrc;
      post-build-hook = uploadHook;
    };

    systemd.tmpfiles.rules = ["d ${queueDirectory} 0700 root root -"];

    systemd.services.nix-store-cache-expire = {
      description = "Expire old Nix store cache queue entries";
      unitConfig.RequiresMountsFor = [queueDirectory];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = expireQueue;
      };
    };

    systemd.timers.nix-store-cache-expire = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };

    systemd.services.nix-store-cache-upload = {
      description = "Asynchronous Nix store cache uploads";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "agenix.service"];
      unitConfig.RequiresMountsFor = [queueDirectory cfg.tokenFile];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${queueDirectory}";
        ExecStart = uploadQueue;
        Restart = "always";
        RestartSec = "5s";
        UMask = "0077";
      };
    };

    systemd.services.nix-daemon = {
      after = ["agenix.service"];
      unitConfig.RequiresMountsFor = [cfg.tokenFile];
      # Determinate writes netrc-file after nix.custom.conf. Environment settings
      # take precedence without publishing the cache token in its shared netrc.
      environment.NIX_CONFIG = lib.mkIf determinateEnabled "netrc-file = ${daemonNetrc}";
      serviceConfig = {
        RuntimeDirectory = "nix-store-cache";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = [prepareNetrc];
      };
    };
  };
}
