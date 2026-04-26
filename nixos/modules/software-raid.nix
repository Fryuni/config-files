{
  config,
  pkgs,
  ...
}: let
  gotifyUrl = "https://gotify.vps1.fryuni.dev";
  gotifyToken = config.age.secrets.software-raid-gotify-token;
  mdadmGotifyAlert = pkgs.writeShellScript "mdadm-gotify-alert" ''
    set -eu

    event="$1"
    array="$2"
    component="''${3:-unknown}"
    token="$(${pkgs.coreutils}/bin/tr -d '\n' < "${gotifyToken.path}")"

    message="$(${pkgs.coreutils}/bin/printf 'mdadm event: %s\narray: %s\ncomponent: %s\nhost: %s\n' "$event" "$array" "$component" "${config.networking.hostName}")"
    payload="$(${pkgs.jq}/bin/jq -n --arg title "${config.networking.hostName} RAID alert: $event" --arg message "$message" --argjson priority 8 '{title: $title, message: $message, priority: $priority}')"

    ${pkgs.coreutils}/bin/printf '%s\n' "header = \"X-Gotify-Key: $token\"" | ${pkgs.curl}/bin/curl --fail --silent --show-error --config - --header "Content-Type: application/json" --data-binary "$payload" "${gotifyUrl}/message"
  '';
in {
  age.secrets.software-raid-gotify-token.rekeyFile = ../../secrets/gotify-token;

  boot.swraid = {
    enable = true;
    mdadmConf = ''
      PROGRAM ${mdadmGotifyAlert}
    '';
  };
}
