pkgs: {
  cargo-doctor = {
    buildInputs = with pkgs; [
      openssl
      pkg-config
    ];
  };
}
