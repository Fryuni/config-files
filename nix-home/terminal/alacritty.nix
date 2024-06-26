{
  pkgs,
  config,
  ...
}: {
  programs.alacritty.enable = true;
  programs.alacritty.settings = {
    window = {
      dimensions.columns = 0;
      dimensions.lines = 0;

      decorations = "full";
      dynamic_title = true;

      startup_mode = "Maximized";
    };

    font = let
      family = "JetBrainsMono Nerd Font";
    in {
      normal = {
        inherit family;
        style = "Regular";
      };
      bold = {
        inherit family;
        style = "Bold";
      };
      italic = {
        inherit family;
        style = "Italic";
      };
    };
  };

  programs.ssh.package = pkgs.symlinkJoin {
    name = "openssh-fixed-term";
    paths = [pkgs.openssh];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      rm -f $out/bin/ssh
      makeWrapper ${pkgs.openssh}/bin/ssh $out/bin/ssh --set TERM xterm-256color
    '';
  };
}
