pkgs: {
  cargo-doctor = {
    nativeBuildInputs = with pkgs; [pkg-config];
    buildInputs = with pkgs; [openssl];
  };
  cargo-edit = {
    nativeBuildInputs = with pkgs; [pkg-config];
    buildInputs = with pkgs; [openssl];
  };
}
