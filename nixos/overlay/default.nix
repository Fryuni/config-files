fixed: prev:
{
  overlay-test = fixed.writeShellScriptBin "overlay-hello" ''
    echo "This hellow world came from the custom derivation inside the overlay."
  '';
}
