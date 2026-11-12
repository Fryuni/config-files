#!/usr/bin/env bash
# Usage: vm-test.sh <config>
# Boots the flashable image from prepare.sh on an emulated aarch64 `virt`
# machine through U-Boot and extlinux, as the Pi firmware would, then checks it
# over SSH. A throwaway SSH key is added to this test copy only.
set -euo pipefail

config=${1:-rpi3}
port=${SSH_PORT:-$(shuf -i 20000-60000 -n 1)}
here=$(dirname "$(realpath "$0")")
cd "$here/../.."
dir=$(mktemp -d)
qemu_pid=
cleanup() {
  [[ -n $qemu_pid ]] && kill "$qemu_pid" 2> /dev/null || true
  rm -rf "$dir"
}
trap cleanup EXIT

"$here/prepare.sh" "$config" "$dir/sd.img"

# Log in as lotus with a throwaway key through ~/.ssh/authorized_keys.
ssh-keygen -q -t ed25519 -N "" -f "$dir/id"
start=$(sfdisk --json "$dir/sd.img" | jq '.partitiontable.partitions[1].start')
debugfs -w -f - "$dir/sd.img?offset=$((start * 512))" > /dev/null 2>&1 <<EOF
mkdir /home
mkdir /home/lotus
mkdir /home/lotus/.ssh
write $dir/id.pub /home/lotus/.ssh/authorized_keys
sif /home uid 0
sif /home gid 0
sif /home/lotus mode 040700
$(for path in /home/lotus /home/lotus/.ssh /home/lotus/.ssh/authorized_keys; do
  printf 'sif %s uid 1000\nsif %s gid 100\n' "$path" "$path"
done)
EOF

# Grow the "card" so first-boot partition expansion has something to do.
truncate -s 8G "$dir/sd.img"

uboot=$(nix build --no-link --print-out-paths .#legacyPackages.aarch64-linux.ubootQemuAarch64)
nix shell nixpkgs#qemu -c qemu-system-aarch64 \
  -machine virt -cpu cortex-a53 -smp 4 -m 1024 \
  -bios "$uboot/u-boot.bin" \
  -drive "if=none,id=sd,format=raw,file=$dir/sd.img" -device virtio-blk-pci,drive=sd \
  -netdev "user,id=net,restrict=on,hostfwd=tcp:127.0.0.1:$port-:22" -device virtio-net-pci,netdev=net \
  -display none -serial chardev:serial \
  -chardev "socket,id=serial,path=$dir/serial.sock,server=on,wait=on,logfile=$dir/console.log" &
qemu_pid=$!

# restrict=on keeps the guest offline, so it cannot spend a real enrollment key.
# QEMU's U-Boot loads the initrd 60 MiB after the kernel, but this kernel needs
# 70 MiB, so move it. The Pi's U-Boot leaves enough room (kernel 0x80000, initrd 0x5700000).
timeout 600 python3 -I - "$dir/serial.sock" <<'EOF'
import socket, sys, time
s = socket.socket(socket.AF_UNIX)
s.settimeout(300)
for _ in range(300):
    try:
        s.connect(sys.argv[1])
        break
    except OSError:
        time.sleep(0.1)
def expect(text):
    buf = b""
    while text not in buf:
        data = s.recv(4096)
        if not data:
            sys.exit("serial console closed")
        buf = buf[-4096:] + data
expect(b"Hit any key to stop autoboot")
s.sendall(b"\n")
expect(b"=> ")
# Type one echoed character at a time and stay connected until the kernel
# starts: QEMU drops input the emulated UART has not consumed yet when the
# socket closes, which truncated the command.
for ch in b"setenv ramdisk_addr_r 0x48000000; boot":
    s.sendall(bytes([ch]))
    expect(bytes([ch]))
s.sendall(b"\n")
expect(b"Starting kernel")
EOF

# Pinning the repo's host key proves the injected key is the one sshd serves.
echo "[127.0.0.1]:$port $(cat "secrets/host-keys/$config.pub")" > "$dir/known_hosts"
ssh_vm() {
  ssh -i "$dir/id" -p "$port" -o UserKnownHostsFile="$dir/known_hosts" \
    -o StrictHostKeyChecking=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o BatchMode=yes lotus@127.0.0.1 "$@"
}

echo "Waiting for SSH (emulated boot takes several minutes)..." >&2
deadline=$((SECONDS + ${BOOT_TIMEOUT:-1200}))
until ssh_vm true 2> /dev/null; do
  if ((SECONDS > deadline)) || ! kill -0 "$qemu_pid" 2> /dev/null; then
    echo "VM did not become reachable over SSH; console tail:" >&2
    tail -n 50 "$dir/console.log" >&2
    exit 1
  fi
  sleep 10
done

ssh_vm timeout 600 bash -s "$config" <<'EOF'
set -euo pipefail
config=$1
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok: $*"; }

[[ $(hostname) == "$config" ]] || fail "hostname is $(hostname)"; ok "hostname $config"
sudo -n true || fail "passwordless sudo"; ok "passwordless sudo"
# Degraded is expected (see below); waiting just lets boot settle.
timeout 300 systemctl is-system-running --wait > /dev/null || true
for unit in sshd tailscaled; do
  systemctl is-active --quiet "$unit" || fail "$unit is not active"; ok "$unit active"
done
sudo test -s /run/agenix/tailscale-authkey || fail "agenix did not decrypt the Tailscale auth key"
[[ $(sudo stat -c %a /run/agenix/tailscale-authkey) == 400 ]] || fail "auth key permissions"
ok "Tailscale auth key decrypted"
sudo journalctl -b -u tailscaled-autoconnect | grep -q "sending auth key" \
  || fail "tailscaled-autoconnect did not try to enroll"; ok "tailscaled-autoconnect tried to enroll"
# Enrollment cannot succeed offline, so autoconnect is the only allowed failed unit.
units=$(systemctl list-units --failed --plain --no-legend)
failed=$(awk '{print $1}' <<< "$units" | grep -vx tailscaled-autoconnect.service || true)
[[ -z $failed ]] || fail "failed units: $failed"; ok "no unexpected failed units"
size=$(df --output=size -B1G / | tail -1 | tr -d ' ')
((size >= 6)) || fail "root filesystem was not expanded (${size}G)"; ok "root filesystem expanded to ${size}G"
nix path-info /run/current-system > /dev/null || fail "nix daemon cannot query the system closure"
ok "nix daemon works"
EOF
echo "VM test passed for $config" >&2
ssh_vm sudo systemctl poweroff || true
