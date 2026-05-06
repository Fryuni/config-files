{pkgs}: {
  makeAuthWrapper = pkg: envMap:
    (pkgs.symlinkJoin {
      name = "${pkg.name}-authenticated";
      nativeBuildInputs = [pkgs.makeWrapper pkgs.coreutils];
      paths = [pkg];
      postBuild = let
        inherit (builtins) isString isAttrs attrNames concatStringsSep;

        mkExport = name: value:
          if isString value
          then ''--set ${name} "${value}"''
          else if isAttrs value && value ? file
          then ''--run 'export ${name}="$(cat "${value.file}")"' ''
          else throw "Invalid env value for ${name}: expected string or { file = path; }";

        exports = map (name: mkExport name envMap.${name}) (attrNames envMap);
        args = concatStringsSep " \\\n" exports + "\n";
      in ''
        for file in ${pkg}/bin/*; do
          originalFile="$(readlink -f "$file")"
          newOut="$out/bin/$(basename $file)"
          rm -rf "$newOut"
          makeWrapper "$originalFile" "$newOut" \
            ${args}
        done
      '';
    }).overrideAttrs (_: {
      inherit (pkg) meta;
    });
}
