{
  pkgs,
  config,
  ...
}: let
  inherit (pkgs) lib;
in {
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];

  services.xserver.videoDrivers = ["nvidia"];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-gmmlib
      intel-media-driver
      # intel-ocl
      libvdpau-va-gl
      vaapiIntel
      vaapiVdpau

      # rocm-opencl-icd
      # rocm-opencl-runtime
      nvidia-vaapi-driver
    ];
  };
  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta;

    prime = {
      sync.enable = true;

      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  specialisation = {
    on-the-go.configuration = {
      system.nixos.tags = ["on-the-go"];
      hardware.nvidia = {
        prime.offload.enable = lib.mkForce true;
        prime.offload.enableOffloadCmd = lib.mkForce true;
        prime.sync.enable = lib.mkForce false;
      };
    };
  };
}
