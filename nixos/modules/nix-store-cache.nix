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

  stateDirectory = "/var/lib/nix-store-cache";
  uploadedCounterName = "uploads-total";
  failedCounterName = "upload-failures-total";
  expiredCounterName = "expired-total";
  metricsFile = "${cfg.metrics.textfileDirectory}/nix-store-cache.prom";

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

  # Upload workers run concurrently, so the read-modify-write is serialized under a
  # lock and published by rename; the collector then never observes a torn value.
  bumpCounter = pkgs.writeShellScript "bump-nix-store-cache-counter" ''
    set -eu
    umask 077
    file="$1"
    delta="''${2:-1}"
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$file")"
    exec 9>"$file.lock"
    ${pkgs.util-linux}/bin/flock 9
    current=0
    if [ -s "$file" ]; then
      read -r current < "$file" || current=0
    fi
    case "$current" in
      "" | *[!0-9]*) current=0 ;;
    esac
    ${pkgs.coreutils}/bin/printf '%s\n' "$((current + delta))" > "$file.tmp"
    ${pkgs.coreutils}/bin/mv -f "$file.tmp" "$file"
  '';

  # Telemetry is best effort: a counter problem must not fail an upload or a sweep.
  recordUpload = lib.optionalString cfg.metrics.enable ''
    ${bumpCounter} ${stateDirectory}/${uploadedCounterName} || true
  '';
  recordFailure = lib.optionalString cfg.metrics.enable ''
    ${bumpCounter} ${stateDirectory}/${failedCounterName} || true
  '';
  # Spliced into expireQueue, so it reads that script's $state and $expired locals.
  recordExpired = lib.optionalString cfg.metrics.enable ''
    ${bumpCounter} "$state/${expiredCounterName}" \
      "$(${pkgs.coreutils}/bin/printf '%s\n' "$expired" | ${pkgs.coreutils}/bin/wc -l)" || true
  '';

  uploadPath = pkgs.writeShellScript "upload-nix-store-cache-path" ''
    set -eu
    # The expiration service may remove an entry after the queue scan.
    path="$(${pkgs.coreutils}/bin/readlink "$1")" || exit 0
    if ${pkgs.cachix}/bin/cachix --host ${lib.escapeShellArg cfg.endpoint} push main \
      "$path"; then
      ${pkgs.coreutils}/bin/rm -f "$1"
      ${recordUpload}
    else
      echo "warning: upload failed for $path; retaining GC root for retry" >&2
      ${recordFailure}
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

  # Positional arguments keep the sweep drivable from the module check against a
  # fixture queue instead of the live GC-root directory.
  expireQueue = pkgs.writeShellScript "expire-nix-store-cache-queue" ''
    set -eu
    queue="$1"
    state="$2"
    max_age="$3"
    if [ -d "$queue" ]; then
      # Inspect symlink mtime, not target timestamps or access times from retries.
      expired="$(${pkgs.findutils}/bin/find "$queue" -ignore_readdir_race -maxdepth 1 \
        -type l ! -newermt "$max_age seconds ago" \
        -delete -printf 'Expired cache queue entry: %f\n')"
      if [ -n "$expired" ]; then
        ${pkgs.coreutils}/bin/printf '%s\n' "$expired"
        ${recordExpired}
      fi
    fi
  '';

  # Positional arguments keep the collector drivable from the module check against
  # a fixture queue instead of the live GC-root directory.
  collectMetrics = pkgs.writeShellScript "collect-nix-store-cache-metrics" ''
    set -eu
    queue="$1"
    state="$2"
    output="$3"

    # Counters are published by rename, so an absent or unparsable file means the
    # counter was never incremented rather than that a read was torn.
    read_counter() {
      value=0
      if [ -s "$1" ]; then
        read -r value < "$1" || value=0
      fi
      case "$value" in
        "" | *[!0-9]*) value=0 ;;
      esac
      ${pkgs.coreutils}/bin/printf '%s' "$value"
    }

    pending=0
    oldest=0
    if [ -d "$queue" ]; then
      pending="$(${pkgs.findutils}/bin/find "$queue" -ignore_readdir_race -maxdepth 1 \
        -type l -printf 'x\n' | ${pkgs.coreutils}/bin/wc -l)"
      oldest_epoch="$(${pkgs.findutils}/bin/find "$queue" -ignore_readdir_race -maxdepth 1 \
        -type l -printf '%T@\n' | ${pkgs.coreutils}/bin/sort -n | ${pkgs.coreutils}/bin/head -n 1)"
      if [ -n "$oldest_epoch" ]; then
        oldest=$(($(${pkgs.coreutils}/bin/date +%s) - ''${oldest_epoch%%.*}))
        [ "$oldest" -ge 0 ] || oldest=0
      fi
    fi

    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$output")"
    # The textfile collector rejects partially written files, so publish by rename.
    ${pkgs.coreutils}/bin/printf '%s\n' \
      '# HELP nix_store_cache_queue_pending Store paths queued for upload to the remote Nix cache.' \
      '# TYPE nix_store_cache_queue_pending gauge' \
      "nix_store_cache_queue_pending $pending" \
      '# HELP nix_store_cache_queue_oldest_seconds Age of the oldest queued store path in seconds.' \
      '# TYPE nix_store_cache_queue_oldest_seconds gauge' \
      "nix_store_cache_queue_oldest_seconds $oldest" \
      '# HELP nix_store_cache_uploads_total Store paths accepted by the remote Nix cache.' \
      '# TYPE nix_store_cache_uploads_total counter' \
      "nix_store_cache_uploads_total $(read_counter "$state/${uploadedCounterName}")" \
      '# HELP nix_store_cache_upload_failures_total Failed upload attempts; the entry stays queued for retry.' \
      '# TYPE nix_store_cache_upload_failures_total counter' \
      "nix_store_cache_upload_failures_total $(read_counter "$state/${failedCounterName}")" \
      '# HELP nix_store_cache_expired_total Queue entries dropped by the expiry timer before upload.' \
      '# TYPE nix_store_cache_expired_total counter' \
      "nix_store_cache_expired_total $(read_counter "$state/${expiredCounterName}")" \
      > "$output.tmp"
    ${pkgs.coreutils}/bin/mv -f "$output.tmp" "$output"
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

    metrics = {
      enable = mkOption {
        type = types.bool;
        default = config.services.prometheus.exporters.node.enable;
        defaultText = lib.literalExpression "config.services.prometheus.exporters.node.enable";
        description = "Publish upload queue metrics through the Prometheus node exporter textfile collector. Defaults to following the node exporter so hosts without a scraper do not collect metrics nothing reads.";
      };

      textfileDirectory = mkOption {
        type = types.str;
        default = "/var/lib/prometheus-node-exporter/textfile";
        description = "Directory holding textfile collector output. Created world-readable so the unprivileged node exporter can read it, and wired into the node exporter through `--collector.textfile.directory`.";
      };

      interval = mkOption {
        type = types.str;
        default = "30s";
        example = "1min";
        description = "systemd time span between metric collections. Keep this below the scrape interval so the pending gauge does not go stale between scrapes.";
      };
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
      {
        assertion = cfg.metrics.enable -> lib.hasPrefix "/" cfg.metrics.textfileDirectory;
        message = "services.nixStoreCache.metrics.textfileDirectory must be an absolute path";
      }
    ];

    nix.settings = {
      fallback = true;
      substituters = lib.mkBefore [cfg.endpoint];
      netrc-file = daemonNetrc;
      post-build-hook = uploadHook;
    };

    systemd.tmpfiles.rules =
      ["d ${queueDirectory} 0700 root root -"]
      ++ lib.optionals cfg.metrics.enable [
        "d ${stateDirectory} 0700 root root -"
        # Only the collected metrics are readable; queue contents stay root-only.
        "d ${cfg.metrics.textfileDirectory} 0755 root root -"
      ];

    services.prometheus.exporters.node.extraFlags =
      lib.mkIf cfg.metrics.enable ["--collector.textfile.directory=${cfg.metrics.textfileDirectory}"];

    systemd.services.nix-store-cache-expire = {
      description = "Expire old Nix store cache queue entries";
      unitConfig.RequiresMountsFor = [queueDirectory];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${expireQueue} ${queueDirectory} ${stateDirectory} ${toString cfg.maxQueueAgeSeconds}";
      };
    };

    systemd.timers.nix-store-cache-expire = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };

    systemd.services.nix-store-cache-metrics = mkIf cfg.metrics.enable {
      description = "Collect Nix store cache queue metrics";
      unitConfig.RequiresMountsFor = [queueDirectory stateDirectory];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${collectMetrics} ${queueDirectory} ${stateDirectory} ${metricsFile}";
        # The node exporter reads the published file as an unprivileged user.
        UMask = "0022";
      };
    };

    systemd.timers.nix-store-cache-metrics = mkIf cfg.metrics.enable {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = cfg.metrics.interval;
        OnUnitActiveSec = cfg.metrics.interval;
        # systemd coalesces timers into one-minute buckets by default, which would
        # let the pending gauge go stale between scrapes.
        AccuracySec = "1s";
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
