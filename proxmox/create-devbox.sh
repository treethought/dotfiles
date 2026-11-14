#!/usr/bin/env bash
# Create a headless Fedora dev VM.
#
#   NODE=pve ./proxmox/create-devbox.sh [name] [vmid]   # create, then bootstrap
#   NODE=pve BOOTSTRAP=0 ./proxmox/create-devbox.sh      # create only
#   ./proxmox/create-devbox.sh                           # run on the node itself
#
# NODE is the machine to create the VM on, so it is only needed when this runs
# somewhere else. Without a vmid the node picks the lowest free one. The guest
# takes a DHCP lease unless IP is set; subnet and gateway come from the node.
set -euo pipefail

VMID=${2:-${VMID:-}}
NAME=${1:-${NAME:-devbox}}
IP=${IP:-}
DNS=${DNS:-1.1.1.1}
BRIDGE=${BRIDGE:-vmbr0}
STORE=${STORE:-local-lvm}
MEMORY=${MEMORY:-8192}
CORES=${CORES:-4}
DISK=${DISK:-48G}
CIUSER=${CIUSER:-treethought}
RELEASE=${RELEASE:-45}
BUILD=${BUILD:-1.4}
SSHKEYS=${SSHKEYS:-/root/.ssh/authorized_keys}
ISO_DIR=/var/lib/vz/template/iso
IMAGE="Fedora-Cloud-Base-Generic-${RELEASE}-${BUILD}.x86_64.qcow2"
BASE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${RELEASE}/Cloud/x86_64/images"

NODE=${NODE:-}
BOOTSTRAP=${BOOTSTRAP:-1}

die() { echo "error: $*" >&2; exit 1; }

# Wrapper mode: hand this file to the node, then continue against the guest.
if [ -n "$NODE" ]; then
  [ -f "$0" ] || die "NODE=... needs this script as a file; run it from the repo"
  vars="VMID='$VMID' NAME='$NAME' IP='$IP' DNS='$DNS' BRIDGE='$BRIDGE' STORE='$STORE'"
  vars="$vars MEMORY='$MEMORY' CORES='$CORES' DISK='$DISK' CIUSER='$CIUSER'"
  vars="$vars RELEASE='$RELEASE' BUILD='$BUILD' SSHKEYS='$SSHKEYS'"
  # tee so the node's progress is visible while still being parsed here.
  out=$(ssh "$NODE" "$vars bash -s" <"$0" | tee /dev/stderr)
  guest_ip=$(printf '%s\n' "$out" | sed -n 's/^GUEST_IP=//p' | tail -1)
  if [ "$BOOTSTRAP" = "0" ]; then
    [ -n "$guest_ip" ] && echo "guest address: $guest_ip"
    exit 0
  fi
  [ -n "$guest_ip" ] || die "the node reported no guest address; run bootstrap-devbox.sh by hand"
  exec "$(dirname "$0")/bootstrap-devbox.sh" --remote "$guest_ip"
fi

fetch() {
  if command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
  else curl -fsSL -o "$2" "$1"; fi
}
if [ "$(id -u)" -ne 0 ] || ! command -v qm >/dev/null 2>&1; then
  die "this half runs on a Proxmox node; from elsewhere use NODE=<host> $0"
fi
[ -r "$SSHKEYS" ] || die "missing $SSHKEYS; cloud-init uses it for login"

# Without an explicit vmid, take the next one after the highest in use.
if [ -z "$VMID" ]; then
  VMID=$(qm list | awk 'NR > 1 && $1 ~ /^[0-9]+$/ {if ($1 > max) max = $1}
    END {print (max < 100) ? 100 : max + 1}')
fi
qm status "$VMID" >/dev/null 2>&1 && die "VM $VMID already exists"

# Derive the network from the bridge: the node already knows its prefix and
# gateway, so nothing here has to be configured per site.
ip link show dev "$BRIDGE" >/dev/null 2>&1 || die "no interface $BRIDGE; pass BRIDGE=<iface>"
BRIDGE_ADDR=$(ip -4 -o addr show dev "$BRIDGE" | awk '{print $4}' | head -1)
[ -n "$BRIDGE_ADDR" ] || die "$BRIDGE has no IPv4 address to derive the subnet from"
PREFIX=${BRIDGE_ADDR#*/}
GW=${GW:-$(ip -4 route show default dev "$BRIDGE" |
  awk '{for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit }}')}
[ -n "$GW" ] || die "no default route on $BRIDGE; pass GW=<addr>"
if [ -n "$IP" ]; then NETCONF="ip=${IP}/${PREFIX},gw=${GW}"; else NETCONF="ip=dhcp"; fi

# The cloud image is the whole point of this path: cloud-init supplies the user,
# keys, and network, so the guest needs no interactive install.
if [ ! -f "${ISO_DIR}/${IMAGE}" ]; then
  echo "downloading ${IMAGE}"
  fetch "${BASE_URL}/${IMAGE}" "${ISO_DIR}/${IMAGE}"
fi
if [ ! -f "${ISO_DIR}/Fedora-Cloud-${RELEASE}-${BUILD}-x86_64-CHECKSUM" ]; then
  fetch "${BASE_URL}/Fedora-Cloud-${RELEASE}-${BUILD}-x86_64-CHECKSUM" \
    "${ISO_DIR}/Fedora-Cloud-${RELEASE}-${BUILD}-x86_64-CHECKSUM"
fi
SUM=/tmp/fedora-cloud.sum
grep "${IMAGE}" "${ISO_DIR}/Fedora-Cloud-${RELEASE}-${BUILD}-x86_64-CHECKSUM" > "$SUM"
(cd "$ISO_DIR" && sha256sum -c "$SUM")

# --cpu host exposes the real CPU flags; qm's default kvm64 model hides them.
qm create "$VMID" --name "$NAME" --ostype l26 \
  --memory "$MEMORY" --cores "$CORES" --cpu host \
  --scsihw virtio-scsi-pci --net0 "virtio,bridge=${BRIDGE}" \
  --agent enabled=1 --serial0 socket --onboot 1

# importdisk leaves the volume attached as unused0, so read the real name back
# instead of assuming vm-<id>-disk-0.
qm importdisk "$VMID" "${ISO_DIR}/${IMAGE}" "$STORE"
VOL=$(qm config "$VMID" | awk -F': ' '/^unused0:/ {print $2}')
[ -n "$VOL" ] || die "import produced no unused disk"
qm set "$VMID" --scsi0 "$VOL" --boot order=scsi0

qm set "$VMID" --ide2 "${STORE}:cloudinit"
qm set "$VMID" --ciuser "$CIUSER" --sshkeys "$SSHKEYS" \
  --ipconfig0 "$NETCONF" --nameserver "$DNS"

# The cloud image ships a small root fs; cloud-init grows it to the disk on boot.
qm resize "$VMID" scsi0 "$DISK"

qm start "$VMID"
echo "started $NAME ($VMID)"

# Wait for the agent to report an address, then hand off to the guest-side
# script. This is why the guest keeps qemu-guest-agent installed: with DHCP
# there is no address to look up anywhere else.
wait_for_address() {
  local addr
  for _ in $(seq 1 60); do
    addr=$(qm guest cmd "$VMID" network-get-interfaces 2>/dev/null |
      awk -F'"' '/"ip-address" *: *"192|"ip-address" *: *"10\.|"ip-address" *: *"172\./ {print $4; exit}')
    if [ -n "$addr" ]; then printf '%s' "$addr"; return 0; fi
    sleep 5
  done
  return 1
}

addr=$(wait_for_address) || die "guest reported no address; use qm terminal $VMID"
echo "VMID=$VMID"
echo "GUEST_IP=$addr"
echo "console: qm terminal $VMID"
