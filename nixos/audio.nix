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
    wireplumber.enable = true;
  };
}
