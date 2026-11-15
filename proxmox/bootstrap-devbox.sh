#!/usr/bin/env bash
# Turn a Fedora guest into a devbox: Nix, dotfiles, Home Manager, shell.
#
#   ./bootstrap-devbox.sh                    # run on the guest
#   ./bootstrap-devbox.sh --remote devbox    # stream it to the guest
#
# Questions are asked first, on whichever machine this starts from, and the
# answers travel to the guest as environment variables. So --remote needs no
# terminal on the guest, and `bash -s < script` behaves the same way.
set -euo pipefail

REMOTE=
case ${1:-} in
  --remote)
    REMOTE=${2:-devbox}
    shift 2 2>/dev/null || shift $#
    ;;
  -h | --help)
    sed -n '2,9p' "$0"
    exit 0
    ;;
esac

REPO=${REPO:-https://github.com/treethought/dotfiles.git}
TARGET=${TARGET:-devbox}             # Home Manager target to apply
DIR=${DIR:-$HOME/dotfiles}           # clone location
SSH_KEY=${SSH_KEY:-}                 # private key to install; empty generates one on the guest
TS_AUTHKEY=${TS_AUTHKEY:-}           # tailscale auth key; otherwise a login URL is printed
SETUP_KEY=${SETUP_KEY:-ask}          # ask | 1 | 0
SETUP_TAILSCALE=${SETUP_TAILSCALE:-ask}  # ask | 1 | 0
SETUP_GH=${SETUP_GH:-ask}            # ask | 1 | 0
SETUP_SECRETS=${SETUP_SECRETS:-ask}  # ask | 1 | 0, copy private/secrets.zsh over
SECRETS_FILE=${SECRETS_FILE:-private/secrets.zsh}  # path inside the repo

die() { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Answers come from variables when set, else a prompt when a terminal exists,
# else the default. Nothing below this point asks anything, so the same script
# runs unattended on the guest.
tty_available() { (: </dev/tty) 2>/dev/null; }

# Read one line. When stdin is the terminal, read it directly so readline owns
# the terminal; when it is not (the script itself was piped in), take the line
# from /dev/tty. Mixing the two makes readline echo against the wrong fd.
read_line() {
  local prompt=$1 default=${2:-} answer=
  if [ -t 0 ]; then
    if [ -n "$default" ]; then read -e -i "$default" -r -p "$prompt " answer || answer=$default
    else read -e -r -p "$prompt " answer || answer=""; fi
  else
    printf '%s ' "$prompt" >&2
    read -r answer </dev/tty || answer=$default
  fi
  REPLY_TEXT=$answer
}

ask() {
  local prompt=$1 default=${2:-y} answer= suffix=
  if ! tty_available && [ ! -t 0 ]; then [ "$default" = "y" ]; return; fi
  if [ "$default" = "y" ]; then suffix="[Y/n]"; else suffix="[y/N]"; fi
  read_line "$prompt $suffix"
  answer=$REPLY_TEXT
  case "$answer" in
    [yY]*) return 0 ;;
    [nN]*) return 1 ;;
    *) [ "$default" = "y" ] ;;
  esac
}

# For string answers. With a terminal it uses readline, so Tab completes paths
# and the default sits ready to edit; the answer lands in REPLY_TEXT so readline
# never runs inside a command substitution.
REPLY_TEXT=
ask_text() {
  local prompt=$1 default=${2:-}
  if ! tty_available && [ ! -t 0 ]; then REPLY_TEXT=$default; return; fi
  read_line "$prompt" "$default"
}

# SSH_KEY answers this too: it is the default at the prompt, so pressing enter
# keeps it, and without a terminal it is used directly.
if [ "$SETUP_KEY" = "ask" ]; then
  ask_text "SSH private key (path, Tab completes; empty generates one; 'skip' for none):" "$SSH_KEY"
  reply=$REPLY_TEXT
  case "$reply" in
    "") SETUP_KEY=1 ;;
    skip | none | -) SETUP_KEY=0 ;;
    *)
      case $reply in "~"*) reply="$HOME${reply#\~}" ;; esac
      [ -r "$reply" ] || die "not readable: $reply"
      # The private half is what authenticates; the public one is derived.
      ssh-keygen -y -f "$reply" >/dev/null 2>&1 ||
        die "$reply is not a usable private key (pass the private half)"
      SSH_KEY=$reply
      SETUP_KEY=1
      ;;
  esac
fi
if [ "$SETUP_TAILSCALE" = "ask" ]; then
  if ask "Install Tailscale and join the tailnet?" y; then
    SETUP_TAILSCALE=1
  else
    SETUP_TAILSCALE=0
  fi
fi
# Secrets are a deliberate copy, not part of the install: a guest without them
# simply cannot reach a provider.
if [ "$SETUP_SECRETS" = "ask" ]; then
  if ask "Copy $SECRETS_FILE to the guest?" n; then SETUP_SECRETS=1; else SETUP_SECRETS=0; fi
fi

if [ "$SETUP_KEY" = "0" ]; then
  SETUP_GH=0 # nothing to register
elif [ "$SETUP_GH" = "ask" ]; then
  if ask "Register this key with GitHub via gh?" n; then SETUP_GH=1; else SETUP_GH=0; fi
fi

# Say what was decided, so a default taken by pressing enter is visible.
onoff() { [ "$1" = "1" ] && echo yes || echo no; }
echo "decisions: ssh key $(onoff "$SETUP_KEY"), tailnet $(onoff "$SETUP_TAILSCALE"), secrets $(onoff "$SETUP_SECRETS"), gh key $(onoff "$SETUP_GH")"

# --remote streams this file to the guest instead of running it here. Answers
# already collected are passed as variables, so the guest side never prompts.
if [ -n "$REMOTE" ]; then
  [ -f "$0" ] || die "--remote needs this script as a file; run it from the repo"

  forward="SETUP_KEY=$SETUP_KEY SETUP_TAILSCALE=$SETUP_TAILSCALE SETUP_GH=$SETUP_GH"
  if [ -n "$TS_AUTHKEY" ]; then forward="$forward TS_AUTHKEY='$TS_AUTHKEY'"; fi

  # A key can only be read where this runs, so copy it over and point the guest
  # at the copy, then remove it once the run ends.
  key_copy=
  if [ -n "$SSH_KEY" ] && [ "$SETUP_KEY" = "1" ]; then
    [ -r "$SSH_KEY" ] || die "SSH_KEY is not readable: $SSH_KEY"
    key_copy="/tmp/bootstrap-key.$$"
    scp -q "$SSH_KEY" "$REMOTE:$key_copy"
    [ -r "$SSH_KEY.pub" ] && scp -q "$SSH_KEY.pub" "$REMOTE:$key_copy.pub"
    forward="$forward SSH_KEY=$key_copy"
  fi

  ssh "$REMOTE" "$forward bash -s" <"$0"
  if [ -n "$key_copy" ]; then ssh "$REMOTE" "rm -f $key_copy $key_copy.pub"; fi

  # The clone exists by now, so there is somewhere to put the file.
  if [ "$SETUP_SECRETS" = "1" ]; then
    src="$(dirname "$0")/../$SECRETS_FILE"
    if [ -r "$src" ]; then
      ssh "$REMOTE" 'mkdir -p ~/dotfiles/private'
      scp -q "$src" "$REMOTE:dotfiles/private/secrets.zsh"
      ssh "$REMOTE" 'chmod 600 ~/dotfiles/private/secrets.zsh'
      echo "copied $SECRETS_FILE to the guest"
    else
      echo "no $src to copy" >&2
    fi
  fi
  exit
fi

# --- apply -------------------------------------------------------------------

# cloud-init runs its own package upgrade on first boot and holds the dnf lock,
# so wait for it rather than sitting on "Waiting for a lock". Reading its state
# needs root, and the upgrade can leave the status call itself wedged, so the
# wait is bounded: dnf waits for the lock on its own if it comes to that.
if have cloud-init; then
  echo "waiting for cloud-init to finish"
  timeout 600 sudo cloud-init status --wait >/dev/null 2>&1 || true
fi

# The cloud image ships curl but not git, and cloud-init gives the user
# passwordless root, so install what the rest of this needs.
if ! have git || ! have curl; then
  echo "installing git and curl"
  sudo dnf install -y git curl
fi
have git || die "git is still missing; install it with dnf and re-run"

# The upstream installer refuses to run on SELinux, which Fedora enforces, so
# this uses the same Determinate installer as the laptop.
if [ ! -e /nix/var/nix/profiles/default ]; then
  echo "installing nix"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    sh -s -- install --no-confirm
fi
if ! have nix && [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
have nix || die "nix is installed but not on PATH; log out and back in"

# Clone on the first run, otherwise update the existing checkout.
if [ ! -d "$DIR/.git" ]; then
  echo "cloning into $DIR"
  git clone "$REPO" "$DIR"
fi
cd "$DIR"
# A clone made before the GitHub rewrite moved into the private config still
# routes https over ssh, which it has no key for.
if ! git pull --ff-only; then
  die "git pull failed. For a clone predating that fix, retry with:
  GIT_CONFIG_GLOBAL=/dev/null git pull --ff-only"
fi

# Generate the shell profile and packages, then link the plain config files.
echo "applying the $TARGET target"
nix run home-manager/master -- switch --flake ".#$TARGET"
./install.sh

# The cloud image logs in with bash. Use the distro's zsh for the login shell so
# a broken Nix store cannot lock the account out; Home Manager still writes the
# shell behaviour.
setup_login_shell() {
  local want=/usr/bin/zsh current
  current=$(getent passwd "$(id -un)" | cut -d: -f7)
  [ "$current" = "$want" ] && return
  if [ ! -x "$want" ]; then
    sudo dnf install -y zsh >/dev/null
  fi
  sudo chsh -s "$want" "$(id -un)"
  echo "login shell set to $want; takes effect on the next login"
}
setup_login_shell

# GitHub refuses anonymous SSH, so the clone above stays on https. A key is
# still what pushes work.
prepare_ssh() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  have ssh-keyscan && ssh-keyscan -t ed25519 github.com >>"$HOME/.ssh/known_hosts" 2>/dev/null || true
}

# Install the key from SSH_KEY, or generate one on the guest.
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

# Install Tailscale when missing, then join. Without TS_AUTHKEY it prints a
# login URL and waits for approval.
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
  # Adding keys needs a scope that gh's default login does not request.
  if ! gh ssh-key list >/dev/null 2>&1; then
    echo "gh lacks the public-key scope; grant it once with:"
    echo "  gh auth refresh -s admin:public_key"
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

if [ "$SETUP_KEY" = "1" ]; then
  prepare_ssh
  setup_ssh_key
fi
[ "$SETUP_TAILSCALE" = "1" ] && join_tailnet
[ "$SETUP_GH" = "1" ] && register_git_key

if [ "$SETUP_SECRETS" = "1" ] && [ ! -r "$DIR/$SECRETS_FILE" ]; then
  echo "note: $DIR/$SECRETS_FILE is missing; copy it from the workstation for the"
  echo "      agent tools to reach a provider"
fi

echo "done: $(hostname -s) is on $TARGET"
