pkgs: {
  cargo-doctor = {
    buildInputs = with pkgs; [
      openssl
      pkg-config
    ];
  };
  cargo-edit = {
    buildInputs = with pkgs; [
      openssl
      pkg-config
    ];
  };
}
