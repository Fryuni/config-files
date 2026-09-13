{
  lib,
  pkgs,
  nixStoreCacheModule,
}: let
  evalModule = extraModule:
    lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      inherit pkgs;
      modules = [
        nixStoreCacheModule
        {
          system.stateVersion = "26.05";

          services.nixStoreCache = {
            enable = true;
            endpoint = "https://cache.example.net";
            tokenFile = "/run/agenix/nix-store-cache-token";
          };
        }
        extraModule
      ];
    };

  # Metric collection follows the node exporter, so both variants must be covered.
  scraped = evalModule {
    services.prometheus.exporters.node.enable = true;
  };
  unscraped = evalModule {};

  scrapedCfg = scraped.config;
  unscrapedCfg = unscraped.config;
  metricsService = scrapedCfg.systemd.services.nix-store-cache-metrics;
  metricsTimer = scrapedCfg.systemd.timers.nix-store-cache-metrics;

  configJson = builtins.toJSON {
    scraped = {
      inherit (scrapedCfg.services.nixStoreCache) metrics;
      exporterFlags = scrapedCfg.services.prometheus.exporters.node.extraFlags;
      tmpfilesRules = scrapedCfg.systemd.tmpfiles.rules;
      inherit (metricsTimer) timerConfig wantedBy;
      inherit (metricsService.serviceConfig) Type UMask;
    };
    unscraped = {
      metricsEnable = unscrapedCfg.services.nixStoreCache.metrics.enable;
      exporterFlags = unscrapedCfg.services.prometheus.exporters.node.extraFlags;
      tmpfilesRules = unscrapedCfg.systemd.tmpfiles.rules;
      hasMetricsService = unscrapedCfg.systemd.services ? nix-store-cache-metrics;
      hasMetricsTimer = unscrapedCfg.systemd.timers ? nix-store-cache-metrics;
    };
  };
in
  pkgs.runCommand "nix-store-cache-module-check" {
    nativeBuildInputs = [pkgs.jq];
    inherit configJson;
    collectCommand = metricsService.serviceConfig.ExecStart;
    expireCommand = scrapedCfg.systemd.services.nix-store-cache-expire.serviceConfig.ExecStart;
  } ''
    printf '%s\n' "$configJson" > config.json

    jq -e '.scraped.metrics.enable == true' config.json
    jq -e '.scraped.metrics.textfileDirectory == "/var/lib/prometheus-node-exporter/textfile"' config.json
    jq -e '.scraped.metrics.interval == "30s"' config.json
    jq -e '.scraped.exporterFlags == ["--collector.textfile.directory=/var/lib/prometheus-node-exporter/textfile"]' config.json
    jq -e '.scraped.tmpfilesRules | any(. == "d /var/lib/nix-store-cache 0700 root root -")' config.json
    jq -e '.scraped.tmpfilesRules | any(. == "d /var/lib/prometheus-node-exporter/textfile 0755 root root -")' config.json
    jq -e '.scraped.tmpfilesRules | any(. == "d /nix/var/nix/gcroots/nix-store-cache 0700 root root -")' config.json
    jq -e '.scraped.wantedBy == ["timers.target"]' config.json
    jq -e '.scraped.timerConfig.OnUnitActiveSec == "30s"' config.json
    jq -e '.scraped.timerConfig.OnBootSec == "30s"' config.json
    jq -e '.scraped.timerConfig.AccuracySec == "1s"' config.json
    jq -e '.scraped.Type == "oneshot"' config.json
    # The node exporter reads the published file as an unprivileged user.
    jq -e '.scraped.UMask == "0022"' config.json

    jq -e '.unscraped.metricsEnable == false' config.json
    jq -e '.unscraped.exporterFlags == []' config.json
    jq -e '.unscraped.hasMetricsService == false' config.json
    jq -e '.unscraped.hasMetricsTimer == false' config.json
    jq -e '.unscraped.tmpfilesRules | any(. == "d /var/lib/nix-store-cache 0700 root root -") | not' config.json
    # The queue itself is unconditional; only its telemetry follows the exporter.
    jq -e '.unscraped.tmpfilesRules | any(. == "d /nix/var/nix/gcroots/nix-store-cache 0700 root root -")' config.json

    # Both maintenance scripts take their paths positionally, so the fixture queue
    # below stands in for the live GC-root directory.
    collect="''${collectCommand%% *}"
    expire="''${expireCommand%% *}"
    queue="$TMPDIR/queue"
    state="$TMPDIR/state"
    output="$TMPDIR/textfile/nix-store-cache.prom"
    mkdir -p "$queue" "$state"

    "$collect" "$queue" "$state" "$output"
    grep -qx '# TYPE nix_store_cache_queue_pending gauge' "$output"
    grep -qx '# TYPE nix_store_cache_uploads_total counter' "$output"
    grep -qx 'nix_store_cache_queue_pending 0' "$output"
    grep -qx 'nix_store_cache_queue_oldest_seconds 0' "$output"
    grep -qx 'nix_store_cache_uploads_total 0' "$output"
    grep -qx 'nix_store_cache_upload_failures_total 0' "$output"
    grep -qx 'nix_store_cache_expired_total 0' "$output"

    # Queue entries are GC roots pointing at real store paths; the fixtures dangle
    # on purpose to prove the collector counts links rather than resolving targets.
    ln -s /nix/store/fixture-fresh-a "$queue/fresh-a"
    ln -s /nix/store/fixture-fresh-b "$queue/fresh-b"
    ln -s /nix/store/fixture-stale "$queue/stale"
    touch -h -d "@$(($(date +%s) - 3600))" "$queue/stale"
    printf '42\n' > "$state/uploads-total"
    printf '7\n' > "$state/upload-failures-total"

    "$collect" "$queue" "$state" "$output"
    grep -qx 'nix_store_cache_queue_pending 3' "$output"
    grep -qx 'nix_store_cache_uploads_total 42' "$output"
    grep -qx 'nix_store_cache_upload_failures_total 7' "$output"

    oldest="$(awk '/^nix_store_cache_queue_oldest_seconds /{print $2}' "$output")"
    if [ "$oldest" -lt 3500 ] || [ "$oldest" -gt 3700 ]; then
      echo "oldest entry age should track the stale fixture, got $oldest" >&2
      exit 1
    fi

    # Sweeping past the age limit drops only the stale entry and counts the drop.
    "$expire" "$queue" "$state" 1800
    test ! -L "$queue/stale"
    test -L "$queue/fresh-a"
    test -L "$queue/fresh-b"

    "$collect" "$queue" "$state" "$output"
    grep -qx 'nix_store_cache_queue_pending 2' "$output"
    grep -qx 'nix_store_cache_expired_total 1' "$output"
    # Counters accumulate rather than reset on each sweep.
    "$expire" "$queue" "$state" 1800
    "$collect" "$queue" "$state" "$output"
    grep -qx 'nix_store_cache_expired_total 1' "$output"
    grep -qx 'nix_store_cache_uploads_total 42' "$output"

    touch $out
  ''
