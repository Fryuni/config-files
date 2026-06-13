{
  # PulseAudio - disabled in favor of PipeWire
  services.pulseaudio.enable = false;
  # https://github.com/NixOS/nixpkgs/pull/258447
  # https://discourse.nixos.org/t/your-system-configures-nixpkgs-with-an-externally-created-instance/33802
  # nixpkgs.config.pulseaudio = true;

  # PipeWire - required for Wayland screensharing
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    systemWide = false;
    wireplumber = {
      enable = true;
      extraConfig."51-built-in-audio-profile" = {
        "wireplumber.settings" = {
          # Do not restore a stale manually selected "Pro Audio" profile.
          # WirePlumber then chooses the higher-priority Analog Stereo Duplex
          # profile for the notebook card, exposing the internal microphone as
          # FL/FR instead of silent AUX0/AUX1 channels in Chromium/OpenWhispr.
          "device.restore-profile" = false;
        };
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "device.name" = "alsa_card.pci-0000_00_1f.3";
              }
            ];
            actions.update-props = {
              "device.profile" = "output:analog-stereo+input:analog-stereo";
            };
          }
        ];
      };
    };
  };
}
