{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  instance = "claw";
  port = 42617;
  inherit (config.services.zeroclaw.instances.${instance}) dataDir;
  configFile = "${dataDir}/config.toml";
  tokensFile = "${dataDir}/.paired-tokens.json";
  yq = lib.getExe pkgs.yq-go;

  # The module regenerates config.toml on every start, but the gateway stores
  # paired dashboard tokens (hashed) in that same file; carry them across.
  savePairedTokens = pkgs.writeShellScript "zeroclaw-${instance}-save-paired-tokens" ''
    set -euo pipefail
    if [[ -s ${configFile} ]]; then
      ${yq} -p toml -o json -I0 '.gateway.paired_tokens // []' ${configFile} > ${tokensFile}
    fi
  '';
  restorePairedTokens = pkgs.writeShellScript "zeroclaw-${instance}-restore-paired-tokens" ''
    set -euo pipefail
    if [[ -s ${tokensFile} ]]; then
      # Not `yq -i`: it chowns its temp file, and the unit's seccomp filter kills chown.
      TOKENS="$(<${tokensFile})" ${yq} -p toml -o toml '.gateway.paired_tokens = env(TOKENS)' ${configFile} > ${configFile}.tmp
      mv -f ${configFile}.tmp ${configFile}
    fi
  '';
in {
  imports = ["${inputs.zeroclaw}/nix/module.nix"];

  age.secrets.zeroclaw-env = {
    rekeyFile = ../../secrets/rpi3/zeroclaw-env;
    generator.script = {pkgs, ...}: ''
      printf 'MATRIX_PASSWORD=%s\n' "$(${lib.getExe pkgs.openssl} rand -hex 32)"
    '';
  };
  # EXECUTOR_TOKEN: an organization-scoped Executor personal access token.
  age.secrets.zeroclaw-executor-env.rekeyFile = ../../secrets/rpi3/executor-env;

  services.zeroclaw.instances.${instance} = {
    environmentFile = config.age.secrets.zeroclaw-env.path;
    settings = {
      # Without it, aliased sections like channels.matrix.<alias> parse as v1 and are dropped.
      schema_version = 3;

      providers.models.custom.loem = {
        # Loem's CLIProxyAPI needs no client key, but without one ZeroClaw treats the
        # provider as unconfigured and the dashboard hides it.
        api_key = "loem";
        uri = "https://llm.loem.lferraz.dev/v1";
        model = "gpt-6.1-sol";
        # ZeroClaw's built-in reasoning filter does not recognize GPT 6 yet.
        provider_extra = {
          reasoning_effort = "high";
          service_tier = "priority";
        };
        # ZeroClaw trusts only webpki roots unless given the Tailnet CA.
        tls_ca_cert_path = "${../../common/certs/lferraz-tailnet-ca.crt}";
      };

      # Upstream's YOLO preset: no approval prompts or shell/path policy. The systemd
      # hardening still applies, and only the owner can reach the agent on Matrix.
      risk_profiles.yolo = {
        level = "full";
        auto_approve = ["*"];
        always_ask = [];
        allowed_commands = ["*"];
        forbidden_paths = [];
        workspace_only = false;
        require_approval_for_medium_risk = false;
        block_high_risk_commands = false;
        sandbox_enabled = false;
        delegation_policy.mode = "allow";
      };
      agents.assistant = {
        model_provider = "custom.loem";
        risk_profile = "yolo";
        channels = ["matrix.lferraz"];
        mcp_bundles = ["executor"];
      };

      mcp.servers = [
        {
          name = "executor";
          transport = "http";
          # Plain HTTP over the Tailnet: ZeroClaw's MCP client trusts only public CAs.
          url = "http://executor.loem.lferraz.dev/mcp";
          headers.Authorization = "Bearer $EXECUTOR_TOKEN";
        }
      ];
      mcp_bundles.executor.servers = ["executor"];

      channels.matrix.lferraz = {
        enabled = true;
        homeserver = "https://matrix.lferraz.com";
        user_id = "@claw:lferraz.com";
        password = "$MATRIX_PASSWORD";
      };
      # The homeserver federates, so only the owner may reach the agent.
      peer_groups.owner = {
        channel = "matrix.lferraz";
        agents = ["assistant"];
        external_peers = ["@luiz:lferraz.com"];
      };

      gateway = {
        inherit port;
        # Rate-limit pairing per Tailnet client instead of exempting Caddy's loopback.
        trust_forwarded_headers = true;
        # Nix manages the version.
        check_updates = false;
      };
    };
  };

  environment.systemPackages = [
    # For `zeroclaw gateway get-paircode --new` when pairing more browsers.
    config.services.zeroclaw.instances.${instance}.package
    pkgs.gws
  ];

  systemd.services."zeroclaw-${instance}" = {
    # Channel startup validates the runtime shell, even before receiving messages.
    path = [pkgs.bash];
    serviceConfig = {
      # Loaded alongside the module's environmentFile, before the config is rendered.
      EnvironmentFile = [config.age.secrets.zeroclaw-executor-env.path];
      ExecStartPre = lib.mkMerge [
        (lib.mkBefore ["${savePairedTokens}"])
        (lib.mkAfter ["${restorePairedTokens}"])
      ];
    };
  };

  services.lferrazTailnetAccess.proxy.aliases.claw = port;

  # shortcut: the dashboard drops provider aliases; revisit for multiple custom endpoints
  # or when upstream sends the full provider reference.
  services.caddy.virtualHosts = lib.genAttrs ["tailnet" "tailnet-no-tls"] (_: {
    extraConfig = lib.mkBefore ''
      @claw_model_catalog {
        host claw.rpi3.lferraz.dev
        path /api/config/catalog/models
        query provider=custom
      }
      rewrite @claw_model_catalog /api/config/catalog/models?provider=custom.loem
    '';
  });
}
