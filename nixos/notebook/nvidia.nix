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

  # NVIDIA environment variables (work for both X11 and Wayland)
  environment.sessionVariables = {
    # Use NVIDIA GBM backend (needed for Wayland compositors)
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Use legacy DRM flip (helps with some rendering issues)
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";

    # Electron/Chromium hardware acceleration
    LIBVA_DRIVER_NAME = "nvidia";
  };

  services.xserver.videoDrivers = ["nvidia"];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-gmmlib
      intel-media-driver
      # intel-ocl
      libvdpau-va-gl
      intel-vaapi-driver
      libva-vdpau-driver

      # rocm-opencl-icd
      # rocm-opencl-runtime
      nvidia-vaapi-driver
    ];
  };
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
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
