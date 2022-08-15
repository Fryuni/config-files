{
  environment.variables = {
    AE_SINK = "ALSA";
    SDL_AUDIODRIVER = "pipewire";
    ALSOFT_DRIVERS = "alsa";
  };

  hardware.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    media-session.enable = false;
    systemWide = false;
    wireplumber.enable = true;
  };
}
