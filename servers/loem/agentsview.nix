{
  home-manager.users.lotus.services.agentsview = {
    enable = true;
    publicOrigin = "https://aview.loem.lferraz.dev";
  };

  services.lferrazTailnetAccess.proxy.aliases.aview = 3377;
}
