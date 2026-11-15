#!/usr/bin/env bash
# Turn a bootstrapped guest into a Proxmox template, after stripping the
# identity that clones must not inherit.
#
#   NODE=root@pve ./proxmox/template-devbox.sh devbox
#   NODE=root@pve ./proxmox/template-devbox.sh 100
#
# Build the guest with SETUP_TAILSCALE=0 SETUP_SECRETS=0 first: a template should
# not carry a tailnet identity or credentials, because every clone would share
# them.
set -euo pipefail

TARGET=${1:-}
NODE=${NODE:-}
DEFAULT_NODE=${DEFAULT_NODE:-root@pve}
YES=${YES:-0}
CIUSER=${CIUSER:-treethought}

die() { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
node() { if [ -n "$NODE" ]; then ssh "$NODE" "$@"; else "$@"; fi; }

[ -n "$TARGET" ] || die "usage: $(basename "$0") <name|vmid>"
if [ -z "$NODE" ] && ! have qm; then
  NODE=$DEFAULT_NODE
fi

if [ "$TARGET" -eq "$TARGET" ] 2>/dev/null; then
  VMID=$TARGET
  NAME=$(node "qm config $VMID" 2>/dev/null | sed -n 's/^name: //p') || true
  [ -n "$NAME" ] || die "no VM with id $VMID"
else
  NAME=$TARGET
  VMID=$(node "qm list" | awk -v n="$NAME" '$2 == n {print $1; exit}')
  [ -n "$VMID" ] || die "no VM named $NAME"
fi
echo "target: $NAME ($VMID)"

tty_available() { (: </dev/tty) 2>/dev/null; }
ask() {
  local prompt=$1 default=${2:-y} answer=
  if [ "$YES" = "1" ] || ! tty_available; then [ "$default" = "y" ]; return; fi
  if [ "$default" = "y" ]; then printf '%s [Y/n] ' "$prompt"; else printf '%s [y/N] ' "$prompt"; fi
  read -r answer </dev/tty || answer=
  case "$answer" in
    [yY]*) return 0 ;;
    [nN]*) return 1 ;;
    *) [ "$default" = "y" ] ;;
  esac
}

ask "Strip identity from $NAME ($VMID) and make it a template?" n || { echo "aborted"; exit 0; }

# Clones inherit these, and without the agent the create script cannot read the
# address of a clone, so make sure they are set before freezing the template.
node "qm set $VMID --agent enabled=1 --onboot 1" >/dev/null

GUEST_IP=$(node "qm guest cmd $VMID network-get-interfaces 2>/dev/null" |
  awk -F'"' '/"ip-address" *: *"192|"ip-address" *: *"10\.|"ip-address" *: *"172\./ {print $4; exit}' || true)
[ -n "$GUEST_IP" ] || die "guest has no address; start it and run the bootstrap first"
echo "stripping identity through $GUEST_IP"

# What clones must not inherit: cloud-init's instance data (or they will not
# re-run), the machine id, host keys, a tailnet login, and shell history.
ssh -o BatchMode=yes "$CIUSER@$GUEST_IP" '
  set -e
  sudo cloud-init clean --logs --seed
  sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
  sudo rm -f /etc/ssh/ssh_host_*
  sudo rm -rf /var/lib/tailscale
  rm -rf ~/.zsh_history ~/.bash_history ~/.cache/* 2>/dev/null || true
  sudo journalctl --rotate >/dev/null 2>&1 || true
  sudo journalctl --vacuum-time=1s >/dev/null 2>&1 || true
  echo "identity removed"
  sudo poweroff
' || die "could not prepare the guest; is it running and reachable?"

echo "waiting for the guest to stop"
for _ in $(seq 1 30); do
  [ "$(node "qm status $VMID" | awk '{print $2}')" = "stopped" ] && break
  sleep 2
done
[ "$(node "qm status $VMID" | awk '{print $2}')" = "stopped" ] || node "qm stop $VMID --timeout 30"

node "qm template $VMID"
echo "template ready: $NAME ($VMID)"
echo "clone it with: NODE=${NODE:-<node>} FROM_TEMPLATE=$VMID ./proxmox/create-devbox.sh <name>"
