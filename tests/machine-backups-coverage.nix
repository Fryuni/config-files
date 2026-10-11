{
  lib,
  pkgs,
  profiles,
}: let
  cases =
    lib.mapAttrsToList (host: profile: let
      cfg = profile.machine.services.machineBackups;
      # Read the actual Home Manager output independently of the NixOS bridge so
      # an omitted standalone configuration cannot make both sides look empty.
      home = profile.home.services.machineBackups;
      registrations = cfg.directories ++ lib.attrValues cfg.captures ++ home.directories ++ lib.attrValues home.captures;
    in {
      inherit host;
      inherit (cfg) configFile;
      expected = lib.genAttrs ["home" "services"] (scope:
        map (entry: {inherit (entry) name paths kind;})
        (lib.filter (entry: lib.elem scope entry.scopes) registrations));
      nodeRed = lib.optionalAttrs (profile.home.services.node-red.enable or false) {
        path = toString profile.home.services.node-red.userDir;
        units =
          ["node-red.service"]
          ++ lib.optional (profile.home.services.node-red.repo != null) "git-sync-node-red-config.service";
        configuredUnits = map (name: "${name}.service") (lib.attrNames profile.home.systemd.user.services);
        inherit (cfg) user;
        uid = cfg.userUid;
      };
    })
    profiles;
  nodeRedDeclarations = repo:
    (lib.evalModules {
      specialArgs = {inherit pkgs;};
      modules = [
        ../nix-home/modules/node-red.nix
        ../nix-home/modules/machine-backups.nix
        {
          options = {
            xdg.stateHome = lib.mkOption {
              type = lib.types.str;
              default = "/home/fixture/.local/state";
            };
            programs.git.enable = lib.mkEnableOption "fixture Git integration";
            services.git-sync = lib.mkOption {
              type = lib.types.attrs;
              default = {};
            };
            systemd.user.services = lib.mkOption {
              type = lib.types.attrs;
              default = {};
            };
          };
          config.services.node-red = {
            enable = true;
            inherit repo;
          };
        }
      ];
    }).config.services.machineBackups.directories;
in
  pkgs.runCommand "machine-backups-coverage-check" {
    nativeBuildInputs = [pkgs.python3];
    casesFile = pkgs.writeText "machine-backups-coverage-cases.json" (builtins.toJSON {
      inherit cases;
      nodeRedWithoutRepository = nodeRedDeclarations null;
    });
  } ''
    python3 - "$casesFile" <<'PY'
    import json
    import sys
    from pathlib import Path

    cases = json.loads(Path(sys.argv[1]).read_text())
    plain_node_red, = cases["nodeRedWithoutRepository"]
    assert plain_node_red["name"] == "node-red"
    assert [unit["name"] for unit in plain_node_red["units"]] == ["node-red.service"], "Node-RED without a repository must not stop git-sync"

    for case in cases["cases"]:
        config = json.loads(Path(case["configFile"]).read_text())
        for scope, expected in case["expected"].items():
            actual = {entry["name"]: entry for entry in config["scopes"][scope]["captures"]}
            for entry in expected:
                assert entry["name"] in actual, (case["host"], scope, "missing capture", entry)
                capture = actual[entry["name"]]
                assert capture["paths"] == entry["paths"], (case["host"], scope, "wrong paths", entry)
                assert capture["kind"] == entry["kind"], (case["host"], scope, "wrong protocol", entry)
                if scope == "home":
                    assert "directExcludes" not in config["scopes"][scope], "Home application files must be read directly"
            if case["nodeRed"]:
                node_red = actual["node-red"]
                owner = case["nodeRed"]
                assert node_red["paths"] == [owner["path"]]
                assert set(owner["units"]) <= set(owner["configuredUnits"]), "Node-RED capture must name configured user services"
                expected_units = [{"name": name, "type": "user", "user": owner["user"], "uid": owner["uid"]} for name in owner["units"]]
                assert node_red["units"] == expected_units, (case["host"], scope, "Node-RED writers are not coordinated", node_red["units"])
        print(case["host"], "service-owned backup coverage passed")
    PY
    touch "$out"
  ''
