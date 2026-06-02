{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    docker-compose
  ];

  virtualisation = {
    # containerd.enable = true;
    oci-containers.backend = "docker";
    docker = {
      enable = true;

      autoPrune.enable = true;
      autoPrune.dates = "weekly";
      autoPrune.flags = ["--all"];

      daemon.settings = {
        registry-mirrors = ["https://mirror.gcr.io"];
      };
    };
  };
}
