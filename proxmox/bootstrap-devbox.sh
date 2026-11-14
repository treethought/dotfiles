#!/usr/bin/env bash
# Turn a fresh Fedora guest into a devbox: Nix, dotfiles, Home Manager, shells.
# Run it on the guest for the interactive prompts, or stream it over SSH, where
# the optional steps come from the variables below instead of questions.
set -euo pipefail

REPO=${REPO:-https://github.com/treethought/dotfiles.git}
TARGET=${TARGET:-devbox}
DIR=${DIR:-$HOME/dotfiles}
SSH_KEY=${SSH_KEY:-}       # private key to install instead of generating one
TS_AUTHKEY=${TS_AUTHKEY:-} # tailscale auth key; otherwise a login URL is printed
SKIP_TAILSCALE=${SKIP_TAILSCALE:-0}
SETUP_GH=${SETUP_GH:-ask}  # ask | 1 | 0

die() { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Prompts read /dev/tty because stdin is the script itself when it is piped in
# over SSH. Without a tty the default is used, which keeps automation quiet.
tty_available() { (: </dev/tty) 2>/dev/null; }
ask() {
  local prompt=$1 default=${2:-y} answer=
  if ! tty_available; then [ "$default" = "y" ]; return; fi
  if [ "$default" = "y" ]; then printf '%s [Y/n] ' "$prompt"; else printf '%s [y/N] ' "$prompt"; fi
  read -r answer </dev/tty || answer=
  case "$answer" in
    [yY]*) return 0 ;;
    [nN]*) return 1 ;;
    *) [ "$default" = "y" ] ;;
  esac
}

# --- core --------------------------------------------------------------------

have git || die "git is missing; run: sudo dnf install -y git curl"
have curl || die "curl is missing; run: sudo dnf install -y git curl"

# The upstream Nix installer refuses to run on SELinux, which Fedora enforces,
# so this uses the same Determinate installer as the laptop.
if [ ! -e /nix/var/nix/profiles/default ]; then
  echo "installing nix"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    sh -s -- install --no-confirm
fi
if ! have nix && [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
have nix || die "nix is installed but not on PATH; log out and back in"

if [ ! -d "$DIR/.git" ]; then
  echo "cloning into $DIR"
  git clone "$REPO" "$DIR"
fi
cd "$DIR"
# A guest cloned before the GitHub rewrite moved to the private config will
# still route its https remote over ssh, which it has no key for.
if ! git pull --ff-only; then
  die "git pull failed. For a clone predating that fix, retry with:
  GIT_CONFIG_GLOBAL=/dev/null git pull --ff-only"
fi

echo "applying $TARGET"
nix run home-manager/master -- switch --flake ".#$TARGET"
./install.sh

# --- optional setup ----------------------------------------------------------

# GitHub refuses anonymous SSH, so the clone above stays on https. A key is
# still what pushes work.
prepare_ssh() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  have ssh-keyscan && ssh-keyscan -t ed25519 github.com >>"$HOME/.ssh/known_hosts" 2>/dev/null || true
}

setup_ssh_key() {
  if [ -n "$SSH_KEY" ]; then
    [ -r "$SSH_KEY" ] || die "SSH_KEY is not readable: $SSH_KEY"
    install -m 600 "$SSH_KEY" "$HOME/.ssh/id_ed25519"
    if [ -r "$SSH_KEY.pub" ]; then
      install -m 644 "$SSH_KEY.pub" "$HOME/.ssh/id_ed25519.pub"
    elif ! ssh-keygen -y -f "$HOME/.ssh/id_ed25519" >"$HOME/.ssh/id_ed25519.pub" 2>/dev/null; then
      die "could not derive a public key from $SSH_KEY"
    fi
    return
  fi
  [ -f "$HOME/.ssh/id_ed25519" ] && return
  echo "generating an ssh key for this guest"
  ssh-keygen -q -t ed25519 -N '' -C "$(hostname -s)-$(date +%F)" -f "$HOME/.ssh/id_ed25519"
}

join_tailnet() {
  have tailscale || {
    # The installer writes to /usr/bin and enables a system unit.
    echo "installing tailscale"
    curl -fsSL https://tailscale.com/install.sh | sudo sh
  }

  local short log url pid
  short=$(hostname -s)
  if tailscale status --json 2>/dev/null | grep -q '"BackendState":[[:space:]]*"Running"'; then
    echo "tailscale already up"
    return
  fi
  if [ -n "$TS_AUTHKEY" ]; then
    sudo tailscale up --authkey "$TS_AUTHKEY" --hostname "$short"
    return
  fi
  # Print the login URL as soon as tailscaled emits it, then keep waiting so the
  # script ends only once the node is on the tailnet.
  log=$(mktemp)
  sudo tailscale up --hostname "$short" >"$log" 2>&1 &
  pid=$!
  for _ in $(seq 1 40); do
    url=$(grep -o 'https://login\.tailscale\.com/[^ ]*' "$log" | head -1 || true)
    if [ -n "$url" ]; then
      echo "approve this node in a browser:"
      echo "  $url"
      break
    fi
    sleep 0.5
  done
  wait "$pid" || { cat "$log"; die "tailscale login failed"; }
  rm -f "$log"
}

# gh has to be authenticated, so registering the key is opt-in.
register_git_key() {
  local pub="$HOME/.ssh/id_ed25519.pub"
  [ -f "$pub" ] || { echo "no guest key to register"; return; }
  if ! have gh; then
    echo "gh not on PATH; register the key by hand: gh ssh-key add $pub"
    return
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "gh is not authenticated; the key is not registered."
    echo "run 'gh auth login', then:"
    echo "  gh ssh-key add $pub --type authentication --title $(hostname -s)"
    return
  fi
  # An already-registered key fails the add, so accept it when the fingerprint
  # is in the account's list.
  if gh ssh-key add "$pub" --type authentication --title "$(hostname -s)" 2>/dev/null ||
    gh ssh-key list 2>/dev/null | grep -qF "$(ssh-keygen -lf "$pub" | cut -d' ' -f2)"; then
    git -C "$DIR" remote set-url origin git@github.com:treethought/dotfiles.git
    echo "key registered; git now uses ssh for github"
  fi
}

prepare_ssh
if ask "Set up an SSH key on this guest?" y; then
  setup_ssh_key
fi

if [ "$SKIP_TAILSCALE" != "1" ] && ask "Join the tailnet?" y; then
  join_tailnet
fi

if [ "$SETUP_GH" = "1" ] || { [ "$SETUP_GH" = "ask" ] && ask "Register the SSH key with GitHub via gh?" n; }; then
  register_git_key
fi

echo "done: $(hostname -s) is on $TARGET"
