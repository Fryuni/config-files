{...}: {
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  boot.loader.raspberryPi.firmwareConfig = ''
    dtparam=audio=on
  '';
}
