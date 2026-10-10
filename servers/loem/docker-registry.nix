{
  config,
  lib,
  ...
}: {
  services = {
    dockerRegistry = {
      enable = true;
      enableGarbageCollect = true;
      port = 3379;
    };

    machineBackups.directories = lib.mkIf config.services.dockerRegistry.enable [
      {
        name = "docker-registry";
        paths = [config.services.dockerRegistry.storagePath];
        units = [
          {name = "docker-registry.service";}
          {name = "docker-registry-garbage-collect.service";}
        ];
      }
    ];
    lferrazTailnetAccess.proxy.aliases.docker = 3379;
  };
}
