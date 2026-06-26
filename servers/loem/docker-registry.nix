{
  services.dockerRegistry = {
    enable = true;
    enableGarbageCollect = true;
    port = 3379;
  };
  services.lferrazTailnetAccess.proxy.aliases.docker = 3379;
}
