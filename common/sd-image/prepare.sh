#!/usr/bin/env bash
# Usage: prepare.sh <config> <out>
# Writes a raw SD image for nixosConfigurations.<config> to <out>. When
# secrets/<config>/ssh-host-ed25519-key exists, it is decrypted with the agenix
# master identity and written into the root filesystem as the SSH host key,
# without root privileges or mounting.
set -euo pipefail

config=$1
out=$(realpath -m "$2")
cd "$(dirname "$0")/../.."
key_secret="secrets/$config/ssh-host-ed25519-key"
host_pub="secrets/host-keys/$config.pub"
identity=${AGE_IDENTITY:-$HOME/.ssh/id_ed25519}

image=$(nix build --no-link --print-out-paths ".#nixosConfigurations.$config.config.system.build.sdImage")
zstd -d -f "$image"/sd-image/*.img.zst -o "$out"
chmod 600 "$out"

if [[ ! -f $key_secret ]]; then
  echo "No $key_secret; the image will generate its own host key on first boot." >&2
  exit 0
fi

# The root filesystem is the second partition of the sd-image layout.
start=$(sfdisk --json "$out" | jq '.partitiontable.partitions[1].start')
fs="$out?offset=$((start * 512))"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
nix shell nixpkgs#age -c age -d -i "$identity" -o "$tmp/key" "$key_secret"
cp "$host_pub" "$tmp/key.pub"

# debugfs keeps going after a failed command, so `mkdir` on an existing directory
# is harmless; the read-back and e2fsck below catch anything that actually broke.
debugfs -w -f - "$fs" > /dev/null 2>&1 <<EOF
mkdir /etc
mkdir /etc/ssh
write $tmp/key /etc/ssh/ssh_host_ed25519_key
write $tmp/key.pub /etc/ssh/ssh_host_ed25519_key.pub
sif /etc/ssh/ssh_host_ed25519_key mode 0100600
sif /etc/ssh/ssh_host_ed25519_key.pub mode 0100644
$(for path in /etc /etc/ssh /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub; do
  printf 'sif %s uid 0\nsif %s gid 0\n' "$path" "$path"
done)
EOF

# Fail loudly if the key did not land intact with root-only permissions.
debugfs -R "cat /etc/ssh/ssh_host_ed25519_key" "$fs" 2> /dev/null > "$tmp/check"
cmp -s "$tmp/key" "$tmp/check" || { echo "Host key injection failed" >&2; exit 1; }
debugfs -R "stat /etc/ssh/ssh_host_ed25519_key" "$fs" 2> /dev/null |
  grep -q "Mode:  0600" || { echo "Host key has wrong permissions" >&2; exit 1; }
e2fsck -fn "$fs" > /dev/null
echo "Wrote $out with the $config host key ($(cut -d' ' -f2 "$host_pub"))" >&2
