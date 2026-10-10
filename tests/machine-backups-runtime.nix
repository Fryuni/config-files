{pkgs}:
pkgs.runCommand "machine-backups-runtime-check" {
  nativeBuildInputs = with pkgs; [python3 restic rsync postgresql_18 nix coreutils victoriametrics acl util-linux];
} ''
  export XDG_CACHE_HOME="$TMPDIR/cache"
  export XDG_CONFIG_HOME="$TMPDIR/config"
  export XDG_STATE_HOME="$TMPDIR/state"
  mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" common/backups tests
  export NIX_CONFIG="experimental-features = nix-command flakes
  sandbox = false
  substituters =
  builders ="
  export NIX_REMOTE="local?store=$TMPDIR/nix/store&state=$TMPDIR/nix/state&log=$TMPDIR/nix/log"
  cp ${../common/backups/capture.py} common/backups/capture.py
  cp ${../common/backups/runner.py} common/backups/runner.py
  cp ${./backups-capture.py} tests/backups-capture.py
  cp ${./backups-runner.py} tests/backups-runner.py
  python3 -B tests/backups-capture.py
  python3 -B tests/backups-runner.py
  touch $out
''
