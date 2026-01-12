{
  fetchurl,
  fetchzip,
  lib,
  stdenv,
  callPackage,
  autoPatchelfHook,
  glib,
}: let
  pluginsJson = builtins.fromJSON (builtins.readFile ./plugins.json);
  specialPluginsInfo = callPackage ./specialPlugins.nix {};
  fetchPluginSrc = url: hash: let
    isJar = lib.hasSuffix ".jar" url;
    fetcher =
      if isJar
      then fetchurl
      else fetchzip;
  in
    fetcher {
      executable = isJar;
      inherit url hash;
    };
  files = builtins.mapAttrs (key: value: fetchPluginSrc key value) pluginsJson.files;
  ids = builtins.attrNames pluginsJson.plugins;

  mkPlugin = id: file:
    if !specialPluginsInfo ? "${id}"
    then files."${file}"
    else
      stdenv.mkDerivation ({
          name = "jetbrains-plugin-${id}";
          installPhase = ''
            runHook preInstall
            mkdir -p $out && cp -r . $out
            runHook postInstall
          '';
          src = files."${file}";
        }
        // specialPluginsInfo."${id}");

  selectFile = id: ide: build: let
    plugin = pluginsJson.plugins."${id}";
  in
    if !builtins.elem ide plugin.compatible
    then throw "Plugin ${plugin.name} with id ${id} does not support IDE ${ide}"
    else if !plugin.builds ? "${build}"
    then throw "Jetbrains IDEs with build ${build} are not in nixpkgs. Try update_plugins.py with --with-build?"
    else if plugin.builds."${build}" == null
    then throw "Plugin ${plugin.name} with id ${id} does not support build ${build} of IDE ${ide}"
    else plugin.builds."${build}";

  byId =
    builtins.listToAttrs
    (map
      (id: {
        name = id;
        value = ide: build: mkPlugin id (selectFile id ide build);
      })
      ids);

  byName =
    builtins.listToAttrs
    (map
      (id: {
        inherit (pluginsJson.plugins."${id}") name;
        value = byId."${id}";
      })
      ids);
in rec {
  # Only use if you know what youre doing
  raw = {inherit files byId byName;};

  tests = callPackage ./tests.nix {};

  addPlugins = ide: unprocessedPlugins: let
    processPlugin = plugin:
      if lib.isDerivation plugin
      then plugin
      else if byId ? "${plugin}"
      then byId."${plugin}" ide.pname ide.buildNumber
      else if byName ? "${plugin}"
      then byName."${plugin}" ide.pname ide.buildNumber
      else throw "Could not resolve plugin ${plugin}";

    plugins = map processPlugin unprocessedPlugins;
  in
    stdenv.mkDerivation rec {
      pname = meta.mainProgram + "-with-plugins";
      inherit (ide) version;
      src = ide;
      dontInstall = true;
      dontFixup = true;
      passthru.plugins = plugins ++ (ide.plugins or []);
      newPlugins = plugins;
      disallowedReferences = [ide];
      nativeBuildInputs = [autoPatchelfHook] ++ (ide.nativeBuildInputs or []);
      buildInputs = lib.unique ((ide.buildInputs or []) ++ [glib]);

      inherit (ide) meta;

      buildPhase = let
        pluginCmdsLines = map (plugin: "ln -s ${plugin} \"$out\"/${meta.mainProgram}/plugins/${baseNameOf plugin}") plugins;
        pluginCmds = builtins.concatStringsSep "\n" pluginCmdsLines;
      in ''
        cp -r ${ide} $out
        chmod +w -R $out
        IFS=' ' read -ra pluginArray <<< "$newPlugins"
        for plugin in "''${pluginArray[@]}"
        do
          ln -s "$plugin" -t $out/${meta.mainProgram}/plugins/
        done
        sed "s|${ide.outPath}|$out|" \
          -i $(realpath $out/bin/${meta.mainProgram}) \
          -i $(realpath $out/bin/${meta.mainProgram}-remote-dev-server)
        autoPatchelf $out/${meta.mainProgram}/bin
      '';
    };
}
