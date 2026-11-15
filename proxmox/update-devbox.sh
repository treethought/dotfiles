#!/usr/bin/env bash
# Push the committed state of this checkout to a guest that already exists.
#
#   ./proxmox/update-devbox.sh                 # the guest named devbox
#   ./proxmox/update-devbox.sh devbox2
#   ./proxmox/update-devbox.sh devbox2 --agents --secrets
#   ./proxmox/update-devbox.sh devbox2 --repos --git
#
# The guest may be named three ways: a tailnet name (MagicDNS), a LAN address,
# or a VM id. A name that does not resolve is looked up on the node, and its
# address is read from the guest agent there.
#
# Nothing here asks a question: the first-run steps are answered "no", so this
# only pulls, re-applies the flake target, relinks, and reinstalls the tools.
# The flags turn individual first-run steps back on, and --push sends this
# branch to the remote first so the guest has something new to pull.
set -euo pipefail

NODE=${NODE:-root@pve}   # the Proxmox host, used when a name does not resolve
export TARGET=${TARGET:-devbox}

GUEST=
for arg in "$@"; do
  case $arg in
    -h | --help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    --key) SETUP_KEY=1 ;;
    --tailnet) SETUP_TAILSCALE=1 ;;
    --gh) SETUP_GH=1 ;;
    --secrets) SETUP_SECRETS=1 ;;
    --agents) SETUP_AGENTS=1 ;;
    --repos) SETUP_REPOS=1 ;;
    --git) SETUP_GIT=1 ;;
    --dnf) SETUP_DNF=1 ;;
    --obsidian) SETUP_OBSIDIAN=1 ;;
    --push) PUSH=1 ;;
    -*) die_unknown=$arg ;;
    *) GUEST=$arg ;;
  esac
done
die() { echo "error: $*" >&2; exit 1; }
if [ -n "${die_unknown:-}" ]; then die "unknown option $die_unknown"; fi
GUEST=${GUEST:-devbox}

# Default every optional step to off, then let the flags above win. The
# bootstrap reads these from the environment, so exporting is the whole wiring;
# export is unconditional because a flag sets a plain shell variable.
export SETUP_KEY=${SETUP_KEY:-0}
export SETUP_TAILSCALE=${SETUP_TAILSCALE:-0}
export SETUP_GH=${SETUP_GH:-0}
export SETUP_SECRETS=${SETUP_SECRETS:-0}
export SETUP_AGENTS=${SETUP_AGENTS:-0}
export SETUP_REPOS=${SETUP_REPOS:-0}
export SETUP_GIT=${SETUP_GIT:-0}
export SETUP_DNF=${SETUP_DNF:-0}
export SETUP_OBSIDIAN=${SETUP_OBSIDIAN:-0}
# The bootstrap skips key registration when there is no key step to register.
[ "$SETUP_KEY" = "0" ] && [ "$SETUP_GH" = "1" ] &&
  die "--gh needs --key; nothing else installs a key to register"

is_addr() { case $1 in *.* | *:*) return 0 ;; *) return 1 ;; esac; }

node_vmid() {
  ssh -o BatchMode=yes "$NODE" "qm list" 2>/dev/null |
    awk -v n="$1" 'NR > 1 && $2 == n {print $1; exit}'
}

# The agent answers with pretty-printed JSON, but read the address out of the
# value itself so a compact one-liner works too.
node_addr() {
  ssh -o BatchMode=yes "$NODE" "qm guest cmd $1 network-get-interfaces" 2>/dev/null |
    awk '/"ip-address" *:/ {
      line = $0
      sub(/.*"ip-address" *: *"/, "", line)
      sub(/".*/, "", line)
      if (line ~ /^(192\.|10\.|172\.)/) { print line; exit }
    }'
}

# A tailnet name is the useful handle, but MagicDNS only answers once the guest
# has joined, and a guest that has not joined still needs updating. So fall back
# to the node, which knows both the id and, through the agent, the address.
# A bare number is a VM id: getent would read it as the address 0.0.0.<n>.
resolve() {
  local guest=$1 vmid= addr
  is_addr "$guest" && { printf '%s' "$guest"; return 0; }
  case $guest in *[!0-9]*) ;; *) vmid=$guest ;; esac
  if [ -z "$vmid" ] && getent hosts "$guest" >/dev/null 2>&1; then
    printf '%s' "$guest"
    return 0
  fi
  [ -n "$vmid" ] || vmid=$(node_vmid "$guest")
  [ -n "$vmid" ] || return 1
  addr=$(node_addr "$vmid")
  [ -n "$addr" ] || return 1
  printf '%s' "$addr"
}

host=$(resolve "$GUEST") || die "cannot find $GUEST: no tailnet name, no VM of that
  name on $NODE, and no address from its guest agent. Pass the address instead."

ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" true 2>/dev/null ||
  die "cannot ssh to $host ($GUEST). Start the VM and check the key:
  ssh -v treethought@$host"

# The guest pulls from the remote, so a commit that is only local never arrives.
repo=$(cd "$(dirname "$0")/.." && pwd)
if [ "${PUSH:-}" = "1" ]; then
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 ||
    die "--push needs $repo to be a git checkout"
  echo "pushing $repo"
  git -C "$repo" push
fi
if git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
  ahead=$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')
  case $ahead in
    0) ;;
    '?') echo "note: $repo has no upstream, so the guest only sees pushed commits" >&2 ;;
    *) echo "note: $ahead unpushed commit(s) here will not reach the guest" >&2 ;;
  esac
  if [ -n "$(git -C "$repo" status --porcelain)" ]; then
    echo "note: uncommitted changes here are not sent; the guest pulls from git" >&2
  fi
fi

echo "updating $GUEST at $host"
exec "$(dirname "$0")/bootstrap-devbox.sh" --remote "$host"
