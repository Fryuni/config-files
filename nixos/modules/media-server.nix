{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
  ];
  # networking.firewall.logRefusedConnections = false;
  # networking.firewall.logRefusedPackets = false;
  # networking.firewall.allowedUDPPorts = [47771];
  networking.firewall = {
    allowedUDPPorts = [5353]; # For device discovery
    allowedUDPPortRanges = [
      {
        from = 32768;
        to = 61000;
      }
    ]; # For Streaming
    allowedTCPPorts = [8010]; # For gnomecast server
  };
  users.users.jellyfin = {
    extraGroups = [
      # "networkmanager"
      # "wheel"
      # "docker"
      # "wireshark"
      "users"
      "audio"
      "rtkit"
      "dialout"
    ];
  };
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    # dataDir = "/var/lib/jellyfin";
    # port = 8096;
    # httpsPort = 8920;
    # ffmpegPackage = pkgs.ffmpeg-full;
    # extraOptions = ''
    #   # Additional Jellyfin server options can be added here
    # '';

    hardwareAcceleration = {
      enable = true;
      type = "nvenc";
      device = "/dev/dri/renderD128";
    };
    transcoding = {
      enableHardwareEncoding = true;
      enableToneMapping = true;
      # hardwareDecodingCodecs = {
      #   h264 = true;
      #   hevc = true;
      #   hevc10bit = true;
      #   vp8 = true;
      #   vp9 = true;
      # };
      # hardwareEncodingCodecs = {
      #   hevc = true;
      # };
    };
  };

  # systemd.services."jellyfin".serviceConfig.ProtectClock = pkgs.lib.mkForce false;

  systemd.services."jellyfin".serviceConfig = with pkgs.lib; {
    ProtectClock = mkForce [];
    PrivateDevices = mkForce [];
    DeviceAllow = mkForce [];

    # ProtectControlGroups = mkForce [];
    # RestrictAddressFamilies = mkForce [];
    # ProtectHostname = mkForce [];

    # LockPersonality = mkForce [];
    # NoNewPrivileges = mkForce [];
    # PrivateTmp = mkForce [];
    # PrivateUsers = mkForce [];
    # ProcSubset = mkForce [];
    # ProtectKernelLogs = mkForce [];
    # ProtectKernelModules = mkForce [];
    # ProtectKernelTunables = mkForce [];
    # ProtectProc = mkForce [];
    # ProtectSystem = mkForce [];
    # RemoveIPC = mkForce [];
    # RestrictNamespaces = mkForce [];
    # RestrictRealtime = mkForce [];
    # RestrictSUIDSGID = mkForce [];
    # SystemCallArchitectures = mkForce [];
    # SystemCallErrorNumber = mkForce [];
    # SystemCallFilter = mkForce [];
    # UMask = mkForce [];
  };
}
