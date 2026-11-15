#!/usr/bin/env bash
# Destroy a dev VM, after taking its identity off the tailnet and GitHub.
#
#   NODE=root@pve ./proxmox/destroy-devbox.sh devbox2
#   NODE=root@pve ./proxmox/destroy-devbox.sh 202
#
# The cleanup has to happen while the guest still runs, so it goes first: a
# logout from the tailnet inside the guest, and optionally deleting the guest's
# registered key from the GitHub account. Then the VM is destroyed with --purge,
# which also drops it from backup jobs and replication.
set -euo pipefail

TARGET=${1:-}
NODE=${NODE:-}
DEFAULT_NODE=${DEFAULT_NODE:-root@pve}
YES=${YES:-0}
CIUSER=${CIUSER:-treethought}
SETUP_TAILSCALE=${SETUP_TAILSCALE:-ask} # ask | 1 | 0, logout from the tailnet
SETUP_GH=${SETUP_GH:-ask}               # ask | 1 | 0, delete the key on GitHub

die() { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
node() { if [ -n "$NODE" ]; then ssh "$NODE" "$@"; else "$@"; fi; }

[ -n "$TARGET" ] || die "usage: $(basename "$0") <name|vmid>"

# qm lives on the node, so this needs NODE when run anywhere else.
if [ -z "$NODE" ] && ! have qm; then
  NODE=$DEFAULT_NODE
fi

tty_available() { (: </dev/tty) 2>/dev/null; }
ask() {
  local prompt=$1 default=${2:-y} answer=
  if [ "$YES" = "1" ]; then return 0; fi
  if ! tty_available; then [ "$default" = "y" ]; return; fi
  if [ "$default" = "y" ]; then printf '%s [Y/n] ' "$prompt"; else printf '%s [y/N] ' "$prompt"; fi
  read -r answer </dev/tty || answer=
  case "$answer" in
    [yY]*) return 0 ;;
    [nN]*) return 1 ;;
    *) [ "$default" = "y" ] ;;
  esac
}

# Resolve the id and name from either argument form.
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

# Confirm before anything is touched: cleanup changes the guest and the account,
# so it must not happen if the destroy is not going ahead.
ask "Destroy $NAME ($VMID) and its disks?" n || { echo "aborted"; exit 0; }

# The guest address comes from the agent, the same way the create script gets
# it. A stopped or agentless guest simply has no cleanup to do.
GUEST_IP=$(node "qm guest cmd $VMID network-get-interfaces 2>/dev/null" |
  awk -F'"' '/"ip-address" *: *"192|"ip-address" *: *"10\.|"ip-address" *: *"172\./ {print $4; exit}' || true)

if [ -n "$GUEST_IP" ]; then
  echo "guest address: $GUEST_IP"
  HOSTNAME=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$CIUSER@$GUEST_IP" hostname 2>/dev/null || true)
else
  echo "guest has no address; skipping in-guest cleanup"
fi

if [ -n "$GUEST_IP" ] && [ "$SETUP_TAILSCALE" != "0" ]; then
  if ask "Log this guest out of the tailnet?" n; then
    ssh -o BatchMode=yes "$CIUSER@$GUEST_IP" 'sudo tailscale logout' 2>/dev/null || true
    # Logging out revokes the node key but leaves the device registered as
    # offline, and the CLI has no verb to delete it. Until it is removed in the
    # admin console, the next guest with this name is handed a -1 suffix.
    echo "logged out; remove the device in the tailnet admin console to free the name"
  fi
fi

if [ -n "$GUEST_IP" ] && [ "$SETUP_GH" != "0" ] && have gh; then
  pubkey=$(ssh -o BatchMode=yes "$CIUSER@$GUEST_IP" 'cat ~/.ssh/id_ed25519.pub 2>/dev/null' || true)
  if [ -n "$pubkey" ] && ask "Delete this guest's key from GitHub?" n; then
    # The bootstrap titles keys with the hostname, and gh's list is a table
    # (TITLE ID KEY TYPE), so match the title and fall back to the key body.
    body=$(printf '%s' "$pubkey" | awk '{print $2}')
    if keys=$(gh ssh-key list 2>&1); then
      id=$(printf '%s\n' "$keys" | awk -v t="$HOSTNAME" 'NR > 1 && $1 == t {print $2; exit}')
      [ -n "$id" ] || id=$(printf '%s\n' "$keys" | awk -v b="$body" 'index($0, b) {print $2; exit}')
      if [ -n "$id" ]; then
        gh ssh-key delete "$id" --yes >/dev/null && echo "deleted key $id from GitHub"
      else
        echo "no key titled $HOSTNAME on the account"
      fi
    else
      echo "gh cannot list keys; it needs the public-key scope:"
      echo "  gh auth refresh -s admin:public_key"
    fi
  fi
elif [ "$SETUP_GH" != "0" ]; then
  echo "gh not available here; delete the rotated key by hand if it was registered"
fi

node "qm stop $VMID --timeout 30 >/dev/null 2>&1 || true"
node "qm destroy $VMID --purge"
echo "destroyed $NAME ($VMID)"
