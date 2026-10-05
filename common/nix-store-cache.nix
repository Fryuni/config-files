{pkgs}: let
  queueDirectory = "/nix/var/nix/gcroots/nix-store-cache";

  # Used by both the daemon hook and the manual command. The queue argument also
  # lets checks exercise GC roots without touching the live upload queue.
  enqueue = pkgs.writeShellScript "enqueue-nix-store-paths" ''
    set -eu
    umask 077
    queue="$1"
    shift
    ${pkgs.coreutils}/bin/mkdir -p "$queue"
    for path in "$@"; do
      # Direct GC roots retain closures until upload succeeds or the entry expires.
      # Duplicate requests keep the original queue age.
      ${pkgs.coreutils}/bin/ln -sT -- "$path" "$queue/''${path##*/}" 2>/dev/null \
        || test -L "$queue/''${path##*/}"
    done
  '';

  command = pkgs.writeShellApplication {
    name = "nix-store-cache-push";
    runtimeInputs = with pkgs; [coreutils nix];
    text = ''
      usage() {
        echo 'Usage: nix-store-cache-push INSTALLABLE_OR_PATH [...]'
        echo 'Queue build outputs, store paths, or symlinks into the store for cache upload.'
      }
      if [[ "''${1:-}" == --help || "''${1:-}" == -h ]]; then
        usage
        exit 0
      fi
      if [[ "''${1:-}" == -- ]]; then
        shift
      fi
      if (( $# == 0 )); then
        usage >&2
        exit 1
      fi

      # Keep registered roots through later builds, validation, and sudo's wait.
      umask 077
      roots="$(mktemp -d -t nix-store-cache-push.XXXXXXXXXX)"
      trap 'rm -rf -- "$roots"' EXIT
      trap 'exit 129' HUP
      trap 'exit 130' INT
      trap 'exit 143' TERM

      paths=()
      for target in "$@"; do
        build=true
        if [[ -e "$target" || -L "$target" || "$target" == /nix/store/* ]]; then
          resolved="$(realpath -e -- "$target")"
          case "$resolved" in
            /nix/store/*)
              relative="''${resolved#/nix/store/}"
              path="/nix/store/''${relative%%/*}"
              # Opaque store-path context roots the object itself, even a .drv,
              # without realising derivation outputs or copying the object.
              NIX_STORE_CACHE_ROOT_PATH="$path" nix build --impure \
                --expr 'builtins.storePath (builtins.getEnv "NIX_STORE_CACHE_ROOT_PATH")' \
                --out-link "$roots/root-''${#paths[@]}" > /dev/null
              paths+=("$path")
              build=false
              ;;
            *)
              if [[ ! -d "$resolved" || ! -f "$resolved/flake.nix" ]]; then
                echo "Path does not resolve into the Nix store: $target" >&2
                exit 1
              fi
              ;;
          esac
        fi
        if "$build"; then
          # Capture before reading so a failed build cannot be hidden by mapfile.
          outputs="$(nix build --out-link "$roots/root-''${#paths[@]}" --print-out-paths -- "$target")"
          if [[ -z "$outputs" ]]; then
            echo "Installable produced no output paths: $target" >&2
            exit 1
          fi
          while IFS= read -r path; do
            paths+=("$path")
          done <<< "$outputs"
        fi
      done

      # Reject unregistered paths before requesting privileges or changing the queue.
      nix-store --check-validity "''${paths[@]}"
      if (( EUID == 0 )); then
        ${enqueue} ${queueDirectory} "''${paths[@]}"
      else
        # Use the host's setuid sudo wrapper; builds and resolution stay unprivileged.
        sudo -- ${enqueue} ${queueDirectory} "''${paths[@]}"
      fi
      printf 'Queued for cache upload: %s\n' "''${paths[@]}"
    '';
  };
in {
  inherit queueDirectory enqueue command;
}
