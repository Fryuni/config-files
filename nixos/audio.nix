{
  hardware.pulseaudio.enable = true;
  nixpkgs.config.pulseaudio = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = false;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    systemWide = false;
    wireplumber.enable = true;
  };
}
