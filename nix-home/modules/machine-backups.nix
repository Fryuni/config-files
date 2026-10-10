{lib, ...}: {
  options.services.machineBackups = import ../../common/backups/options.nix {inherit lib;};
}
