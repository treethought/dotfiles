#!/usr/bin/env bash
# Create a headless Fedora dev VM.
#
#   NODE=pve ./proxmox/create-devbox.sh [name] [vmid]
#
# The disk comes from the Fedora cloud image; cloud-init supplies the user, keys
# and network, so the guest needs no interactive install.
#
# NODE is the machine to create the VM on. It defaults to root@pve when qm is not
# available locally, and is ignored on a node. Without a vmid the node takes the
# next id above the highest in use. The guest takes a DHCP lease unless IP is
# set; subnet and gateway come from the node. When it finishes, the script prints
# how to reach the guest by address and, once it has joined, by tailnet name.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

name_arg=
vmid_arg=
while [ $# -gt 0 ]; do
  case $1 in
    -h | --help)
      sed -n '2,13p' "$0"
      exit 0
      ;;
    -*) die "unknown option $1" ;;
    *)
      if [ -z "$name_arg" ]; then
        name_arg=$1
      elif [ -z "$vmid_arg" ]; then
        vmid_arg=$1
      else
        die "unexpected argument $1"
      fi
      shift
      ;;
  esac
done

VMID=${vmid_arg:-${VMID:-}}
NAME=${name_arg:-${NAME:-devbox}}
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
DEFAULT_NODE=${DEFAULT_NODE:-root@pve}   # used when qm is not on this machine
BOOTSTRAP=${BOOTSTRAP:-1}
CIUPGRADE=${CIUPGRADE:-0}          # 1 lets cloud-init upgrade packages on first boot

# A destroyed guest leaves its device registered in the tailnet, and Tailscale
# then hands the replacement a -1 suffix, so the guest name and the DNS name
# diverge. Refuse to start in that case instead of creating a confusing guest.
check_tailnet_name() {
  [ "${SETUP_TAILSCALE:-}" = "0" ] && return 0
  command -v tailscale >/dev/null 2>&1 || return 0
  tailscale status 2>/dev/null | awk '{print $2}' | grep -qx "$NAME" || return 0
  die "the tailnet still has a device named $NAME (removed guests stay registered).
  Remove it at https://login.tailscale.com/admin/machines and re-run, or pick
  another name; otherwise the guest joins as $NAME-1 and the names diverge."
}
check_tailnet_name

# On a node the commands run here; anywhere else, assume the node over ssh.
if [ -z "$NODE" ] && ! command -v qm >/dev/null 2>&1; then
  NODE=$DEFAULT_NODE
fi

# Wrapper mode: hand this file to the node, then continue against the guest.
if [ -n "$NODE" ]; then
  [ -f "$0" ] || die "NODE=... needs this script as a file; run it from the repo"
  vars="VMID='$VMID' NAME='$NAME' IP='$IP' DNS='$DNS' BRIDGE='$BRIDGE' STORE='$STORE'"
  vars="$vars MEMORY='$MEMORY' CORES='$CORES' DISK='$DISK' CIUSER='$CIUSER'"
  vars="$vars RELEASE='$RELEASE' BUILD='$BUILD' SSHKEYS='$SSHKEYS'"
  vars="$vars CIUPGRADE='$CIUPGRADE'"
  # tee so the node's progress is visible while still being parsed here.
  out=$(ssh "$NODE" "$vars bash -s" <"$0" | tee /dev/stderr)
  guest_ip=$(printf '%s\n' "$out" | sed -n 's/^GUEST_IP=//p' | tail -1)
  if [ "$BOOTSTRAP" = "0" ]; then
    [ -n "$guest_ip" ] && echo "guest address: $guest_ip"
    exit 0
  fi
  [ -n "$guest_ip" ] || die "the node reported no guest address; run bootstrap-devbox.sh by hand"
  "$(dirname "$0")/bootstrap-devbox.sh" --remote "$guest_ip"
  rc=$?

  echo
  echo "connect:"
  echo "  ssh ${CIUSER}@${guest_ip}"
  # MagicDNS answers only once the guest has joined the tailnet.
  if getent hosts "$NAME" >/dev/null 2>&1; then
    echo "  ssh ${CIUSER}@${NAME}"
  else
    echo "  (tailnet name $NAME will resolve after it joins: ssh ${CIUSER}@${NAME})"
  fi
  exit "$rc"
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

# Wait for the agent to report an address, then hand off to the guest-side
# script. This is why the guest keeps qemu-guest-agent installed: with DHCP
# there is no address to look up anywhere else.
wait_for_address() {
  local addr
  # Without the agent this can only time out, so say so instead of waiting.
  qm config "$VMID" 2>/dev/null | grep -q '^agent: enabled=1' ||
    die "guest agent is off for $VMID; run: qm set $VMID --agent enabled=1 and reboot it"
  for _ in $(seq 1 60); do
    addr=$(qm guest cmd "$VMID" network-get-interfaces 2>/dev/null |
      awk -F'"' '/"ip-address" *: *"192|"ip-address" *: *"10\.|"ip-address" *: *"172\./ {print $4; exit}')
    if [ -n "$addr" ]; then printf '%s' "$addr"; return 0; fi
    sleep 5
  done
  return 1
}

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
qm set "$VMID" --ciuser "$CIUSER" --sshkeys "$SSHKEYS" --ciupgrade "$CIUPGRADE" \
  --ipconfig0 "$NETCONF" --nameserver "$DNS"

# The cloud image ships a small root fs; cloud-init grows it to the disk on boot.
qm resize "$VMID" scsi0 "$DISK"

qm start "$VMID"
echo "started $NAME ($VMID)"


addr=$(wait_for_address) || die "guest reported no address; use qm terminal $VMID"
echo "VMID=$VMID"
echo "GUEST_IP=$addr"
echo "connect: ssh ${CIUSER}@${addr}"
echo "console: qm terminal $VMID"
