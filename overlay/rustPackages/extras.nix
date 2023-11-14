pkgs: {
  cargo-doctor = {
    nativeBuildInputs = with pkgs; [pkg-config];
    buildInputs = with pkgs; [openssl];
  };
  cargo-edit = {
    nativeBuildInputs = with pkgs; [pkg-config];
    buildInputs = with pkgs; [openssl];
  };
  prr = {
    nativeBuildInputs = with pkgs; [pkg-config];
    buildInputs = with pkgs; [openssl];
  };
  zellij = {
    nativeBuildInputs = with pkgs; [
      perl
    ];

    buildInputs = with pkgs; [openssl];

    preCheck = ''
      HOME=$TMPDIR
    '';
  };
}
