pkgs: {
  cargo-doctor = {
    buildInputs = with pkgs; [openssl];
  };
  cargo-docs = {
    buildInputs = with pkgs; [openssl];
  };
  cargo-edit = {
    buildInputs = with pkgs; [openssl];
  };
  prr = {
    buildInputs = with pkgs; [openssl];
  };
  octorus = {
    mainProgram = "or";
    nativeBuildInputs = with pkgs; [autoPatchelfHook];
    buildInputs = with pkgs; [stdenv.cc.cc.lib];
  };
  zellij = {
    nativeBuildInputs = with pkgs; [
      perl
    ];

    buildInputs = with pkgs; [openssl];

    preCheck = ''
      export HOME=$TMPDIR
    '';
  };
}
