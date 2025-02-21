{...}: {
  system.stateVersion = "24.11";
sdImage.compressImage = false;

  users.users.root = {
    initialHashedPassword = "$y$j9T$H83XXMYlvmuldDDk2dp.C0$rgBmux1Bf8gHez.p2WEFXEdpjXnDSTd.8vGU6QgFjiB";
  };

  networking = {
    hostName = "";

    wireless.enable = false;
    useDHCP = false;

    interfaces
  };
}
