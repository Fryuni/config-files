{pkgs}: let
  fixture = pkgs.writeTextDir "bin/tool" "cache command fixture";
  secondFixture = pkgs.writeText "cache-command-second-output" "second output";
  assertRoots = pkgs.writeShellScript "assert-cache-command-roots" ''
    set -eu
    for path in "$@"; do
      rooted=false
      for root in "$TMPDIR"/nix-store-cache-push.*/root*; do
        if [ -L "$root" ] && [ "$(readlink "$root")" = "$path" ]; then
          rooted=true
          break
        fi
      done
      if ! "$rooted"; then
        echo "Store path is unprotected before queue handoff: $path" >&2
        exit 1
      fi
    done
  '';
  fakeNix = pkgs.symlinkJoin {
    name = "cache-command-test-nix";
    paths = [
      (pkgs.writeShellScriptBin "nix" ''
        set -eu
        test "$1" = build
        shift
        root=""
        if [ "$1" = --impure ]; then
          test "$2" = --expr
          test "$3" = 'builtins.storePath (builtins.getEnv "NIX_STORE_CACHE_ROOT_PATH")'
          test "$4" = --out-link
          nix-store --check-validity "$NIX_STORE_CACHE_ROOT_PATH"
          ln -s "$NIX_STORE_CACHE_ROOT_PATH" "$5"
          exit 0
        else
          test "$1" = --out-link
          root="$2"
          shift 2
        fi
        test "$#" -eq 3
        test "$1" = --print-out-paths
        test "$2" = --
        printf '%s\n' "$3" >> "$TMPDIR/builds"
        case "$3" in
          fixture#package | ./local-flake)
            ln -s ${fixture} "$root"
            printf '%s\n' ${fixture}
            ;;
          'fixture#package^*')
            ln -s ${fixture} "$root"
            ln -s ${secondFixture} "$root-dev"
            printf '%s\n' ${fixture} ${secondFixture}
            ;;
          fixture#later)
            # Completed outputs remain rooted while a subsequent target builds.
            ${assertRoots} ${fixture} ${secondFixture}
            ln -s ${fixture} "$root"
            printf '%s\n' ${fixture}
            ;;
          fixture#failure)
            # Even partial stdout must not turn a failed build into an enqueue.
            ln -s ${fixture} "$root"
            printf '%s\n' ${fixture}
            exit 17
            ;;
          fixture#empty) ;;
          *) exit 1 ;;
        esac
      '')
      (pkgs.writeShellScriptBin "nix-store" ''
        set -eu
        test "$1" = --check-validity
        shift
        for path in "$@"; do
          case "$path" in
            ${fixture} | ${secondFixture}) ;;
            *) exit 1 ;;
          esac
        done
      '')
    ];
  };
  cacheCommands = import ../common/nix-store-cache.nix {
    pkgs = pkgs // {nix = fakeNix;};
  };
  fakeSudo = pkgs.writeShellScriptBin "sudo" ''
    set -eu
    test "$1" = --
    test "$2" = ${cacheCommands.enqueue}
    test "$3" = ${cacheCommands.queueDirectory}
    shift 3
    # Authentication may block here after final validation has already passed.
    ${assertRoots} "$@"
    if [ "''${CACHE_PUSH_SUDO_FAIL:-0}" = 1 ]; then
      exit 1
    fi
    printf 'sudo\n' >> "$TMPDIR/sudo-calls"
    ${cacheCommands.enqueue} "$TMPDIR/manual-queue" "$@"
    ${assertRoots} "$@"
  '';
in
  pkgs.runCommand "nix-store-cache-command-check" {
    nativeBuildInputs = [fakeSudo];
    command = pkgs.lib.getExe cacheCommands.command;
  } ''
    fixture=${fixture}
    secondFixture=${secondFixture}
    assert_cleanup() {
      test -z "$(find "$TMPDIR" -maxdepth 1 -type d -name 'nix-store-cache-push.*' -print -quit)"
    }
    expect_failure() {
      if "$command" "$@"; then
        echo "Command unexpectedly succeeded: $*" >&2
        exit 1
      fi
      test ! -e "$TMPDIR/sudo-calls"
      test ! -e "$TMPDIR/manual-queue"
      assert_cleanup
    }

    # Parsing and validation happen before sudo or queue writes.
    "$command" --help
    expect_failure
    mkdir outside-store
    expect_failure ./outside-store
    ln -s /nix/store/missing-cache-command-fixture broken
    expect_failure ./broken
    expect_failure fixture#failure
    expect_failure fixture#empty
    expect_failure ${fixture} fixture#failure
    # Store path resolution still has to pass the Nix validity check.
    expect_failure ${pkgs.coreutils}
    CACHE_PUSH_SUDO_FAIL=1 expect_failure fixture#package

    # A link to a file inside a store object queues the containing store object.
    ln -s ${fixture} 'result with spaces'
    "$command" './result with spaces/bin/tool'
    test "$(readlink "$TMPDIR/manual-queue/''${fixture##*/}")" = ${fixture}
    test "$(stat -c %a "$TMPDIR/manual-queue")" = 700
    assert_cleanup
    # Direct path resolution must not invoke a build.
    test "$(wc -l < "$TMPDIR/builds")" -eq 4

    # Pending duplicates coalesce and preserve their expiry age.
    touch -h -d @1000000000 "$TMPDIR/manual-queue/''${fixture##*/}"
    "$command" ${fixture} ./result\ with\ spaces
    test "$(stat -c %Y "$TMPDIR/manual-queue/''${fixture##*/}")" = 1000000000

    # All selected outputs go to the same queue, even when already built.
    "$command" 'fixture#package^*'
    assert_cleanup
    test "$(readlink "$TMPDIR/manual-queue/''${secondFixture##*/}")" = ${secondFixture}
    test "$(find "$TMPDIR/manual-queue" -type l | wc -l)" -eq 2
    rm "$TMPDIR/manual-queue/''${fixture##*/}"
    "$command" fixture#package
    test -L "$TMPDIR/manual-queue/''${fixture##*/}"

    "$command" ${fixture} 'fixture#package^*' fixture#later
    assert_cleanup

    # Plain local flake directories are valid installable references too.
    mkdir local-flake
    touch local-flake/flake.nix
    "$command" ./local-flake
    test "$(tail -n 1 "$TMPDIR/builds")" = ./local-flake

    # The daemon uses the same helper without requesting sudo.
    ${cacheCommands.enqueue} "$TMPDIR/hook-queue" ${fixture} ${secondFixture}
    test "$(readlink "$TMPDIR/hook-queue/''${fixture##*/}")" = ${fixture}
    test "$(readlink "$TMPDIR/hook-queue/''${secondFixture##*/}")" = ${secondFixture}

    touch "$out"
  ''
