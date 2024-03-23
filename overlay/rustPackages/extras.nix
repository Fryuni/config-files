pkgs: {
  cargo-doctor = {
    buildInputs = with pkgs; [openssl];
  };
  cargo-edit = {
    buildInputs = with pkgs; [openssl];
  };
  prr = {
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
