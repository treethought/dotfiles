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
SETUP_OBSIDIAN=${SETUP_OBSIDIAN:-ask}  # ask | 1 | 0, log in and start Obsidian Sync
SETUP_AGENTS=${SETUP_AGENTS:-ask}    # ask | 1 | 0, copy the agent directory over
SETUP_REPOS=${SETUP_REPOS:-ask}      # ask | 1 | 0, clone the repositories listed below
SETUP_GIT=${SETUP_GIT:-ask}          # ask | 1 | 0, write the git identity on the guest
SETUP_DNF=${SETUP_DNF:-0}            # 1 upgrades the guest's Fedora packages; 0 leaves them
GIT_NAME=${GIT_NAME:-}               # author name; defaults to the private git config
GIT_EMAIL=${GIT_EMAIL:-}             # author email; same default
GIT_LOCAL_FILE=${GIT_LOCAL_FILE:-git/gitconfig.local.private}  # source of those defaults
AGENTS_DIR=${AGENTS_DIR:-$HOME/.agents}  # source, on the machine running this
AGENTS_MD=${AGENTS_MD:-$HOME/AGENTS.md}   # global agent guidance
SECRETS_FILE=${SECRETS_FILE:-private/secrets.zsh}  # path inside the repo
REPOS_FILE=${REPOS_FILE:-private/repos.txt}  # one "owner/name [dir]" per line
REPO_HOME_DEFAULT=$HOME/projects     # where a line without a directory is cloned
REPO_HOME=${REPO_HOME:-$REPO_HOME_DEFAULT}

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

# Where a path named relative to the repo lives on the machine running this.
local_path() {
  case $1 in
    /*) printf '%s' "$1" ;;
    *) printf '%s/%s' "$(dirname "$0")/.." "$1" ;;
  esac
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
if [ "$SETUP_AGENTS" = "ask" ]; then
  if ask "Copy the agent directory and AGENTS.md to the guest?" y; then SETUP_AGENTS=1; else SETUP_AGENTS=0; fi
fi
# Only worth asking when there is a list to clone, so the question is skipped
# rather than answered for a file that does not exist.
if [ "$SETUP_REPOS" = "ask" ]; then
  count=$(grep -cvE '^[[:space:]]*(#|$)' "$(local_path "$REPOS_FILE")" 2>/dev/null || true)
  if [ "${count:-0}" -gt 0 ] &&
    ask "Clone the ${count} repositories listed in $REPOS_FILE?" y; then
    SETUP_REPOS=1
  else
    SETUP_REPOS=0
  fi
fi
# git refuses to commit without an author, and ~/.gitconfig is a symlink into
# the repo, so the identity belongs in the local file it includes. The name and
# email default to the workstation's private config, which is where they are
# already written down.
if [ "$SETUP_GIT" = "ask" ]; then
  if ask "Set the git author on the guest?" y; then SETUP_GIT=1; else SETUP_GIT=0; fi
fi
if [ "$SETUP_GIT" = "1" ]; then
  git_private=$(local_path "$GIT_LOCAL_FILE")
  [ -n "$GIT_NAME" ] ||
    GIT_NAME=$(git config -f "$git_private" user.name 2>/dev/null || true)
  [ -n "$GIT_EMAIL" ] ||
    GIT_EMAIL=$(git config -f "$git_private" user.email 2>/dev/null || true)
  if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    echo "no git author found in $git_private; set GIT_NAME and GIT_EMAIL" >&2
    SETUP_GIT=0
  fi
fi
if [ "$SETUP_OBSIDIAN" = "ask" ]; then
  if ask "Set up Obsidian Sync on this guest (needs the secrets above)?" n; then
    SETUP_OBSIDIAN=1
  else
    SETUP_OBSIDIAN=0
  fi
fi

if [ "$SETUP_KEY" = "0" ]; then
  SETUP_GH=0 # nothing to register
elif [ "$SETUP_GH" = "ask" ]; then
  if ask "Register this key with GitHub via gh?" n; then SETUP_GH=1; else SETUP_GH=0; fi
fi

# Say what was decided, so a default taken by pressing enter is visible.
onoff() { [ "$1" = "1" ] && echo yes || echo no; }
echo "decisions: ssh key $(onoff "$SETUP_KEY"), tailnet $(onoff "$SETUP_TAILSCALE"), secrets $(onoff "$SETUP_SECRETS"), agents $(onoff "$SETUP_AGENTS"), repos $(onoff "$SETUP_REPOS"), git $(onoff "$SETUP_GIT"), dnf $(onoff "$SETUP_DNF"), obsidian $(onoff "$SETUP_OBSIDIAN"), gh key $(onoff "$SETUP_GH")"

# --remote streams this file to the guest instead of running it here. Answers
# already collected are passed as variables, so the guest side never prompts.
if [ -n "$REMOTE" ]; then
  [ -f "$0" ] || die "--remote needs this script as a file; run it from the repo"

  forward="SETUP_KEY=$SETUP_KEY SETUP_TAILSCALE=$SETUP_TAILSCALE SETUP_GH=$SETUP_GH"
  forward="$forward SETUP_SECRETS=$SETUP_SECRETS SETUP_OBSIDIAN=$SETUP_OBSIDIAN"
  forward="$forward SETUP_AGENTS=$SETUP_AGENTS SETUP_REPOS=$SETUP_REPOS"
  forward="$forward SETUP_GIT=$SETUP_GIT SETUP_DNF=$SETUP_DNF"
  if [ -n "$GIT_NAME" ]; then forward="$forward GIT_NAME='$GIT_NAME'"; fi
  if [ -n "$GIT_EMAIL" ]; then forward="$forward GIT_EMAIL='$GIT_EMAIL'"; fi
  if [ -n "$TS_AUTHKEY" ]; then forward="$forward TS_AUTHKEY='$TS_AUTHKEY'"; fi
  # Only an explicit override travels; the default is this machine's home, which
  # is not what the guest's home necessarily is.
  if [ -n "${REPO_HOME:-}" ] && [ "$REPO_HOME" != "$REPO_HOME_DEFAULT" ]; then
    forward="$forward REPO_HOME='$REPO_HOME'"
  fi

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

  # The guest-side script reads the secrets during the run (Obsidian Sync needs
  # them), before the clone exists, so hand over a copy and delete it afterwards.
  secrets_copy=
  if [ "$SETUP_SECRETS" = "1" ]; then
    src="$(dirname "$0")/../$SECRETS_FILE"
    if [ -r "$src" ]; then
      secrets_copy="/tmp/bootstrap-secrets.$$"
      scp -q "$src" "$REMOTE:$secrets_copy"
      forward="$forward SECRETS_FILE=$secrets_copy"
    fi
  fi

  # The repository list is read on the guest during the same window, so it
  # travels the same way. It is a list of names, not a credential, but it names
  # private repositories and stays out of git all the same.
  repos_copy=
  repos_src=$(local_path "$REPOS_FILE")
  if [ "$SETUP_REPOS" = "1" ] && [ -r "$repos_src" ]; then
    repos_copy="/tmp/bootstrap-repos.$$"
    scp -q "$repos_src" "$REMOTE:$repos_copy"
    forward="$forward REPOS_FILE=$repos_copy"
  fi

  ssh "$REMOTE" "$forward bash -s" <"$0"
  if [ -n "$key_copy" ]; then ssh "$REMOTE" "rm -f $key_copy $key_copy.pub"; fi
  if [ -n "$secrets_copy" ]; then ssh "$REMOTE" "rm -f $secrets_copy"; fi
  if [ -n "$repos_copy" ]; then ssh "$REMOTE" "rm -f $repos_copy"; fi

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
  # Keep the list on the guest, so a later run does not have to send it again.
  if [ -n "$repos_copy" ]; then
    ssh "$REMOTE" 'mkdir -p ~/dotfiles/private'
    scp -q "$repos_src" "$REMOTE:dotfiles/private/$(basename "$REPOS_FILE")"
    echo "copied $REPOS_FILE to the guest"
  fi
  # Agents read these at runtime, so copying after the guest is set up keeps the
  # transfer off the critical path.
  if [ "$SETUP_AGENTS" = "1" ]; then
    if [ -d "$AGENTS_DIR" ]; then
      tar -C "$(dirname "$AGENTS_DIR")" -cf - "$(basename "$AGENTS_DIR")" |
        ssh "$REMOTE" 'mkdir -p ~ && tar -C ~ -xf -'
      echo "copied $(basename "$AGENTS_DIR") to the guest"
    else
      echo "no $AGENTS_DIR to copy" >&2
    fi
    if [ -f "$AGENTS_MD" ]; then
      scp -q "$AGENTS_MD" "$REMOTE:AGENTS.md"
      echo "copied $(basename "$AGENTS_MD") to the guest"
    else
      echo "no $AGENTS_MD to copy" >&2
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

# The image's packages are frozen at provisioning, because cloud-init upgrading
# them on first boot bought waiting and lock contention, so this is the only
# thing that moves them. Opt-in: it can pull a kernel and the NVIDIA-free driver
# set with it, which is a decision for the person running it, not for a run that
# was meant to update dotfiles.
if [ "$SETUP_DNF" = "1" ]; then
  echo "upgrading the guest's Fedora packages"
  if sudo dnf upgrade --refresh --assumeyes; then
    echo "packages upgraded; reboot if the kernel or a driver changed"
  else
    echo "package upgrade failed; continuing with what is installed" >&2
  fi
fi

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
if [ -x bin/install-tools.sh ]; then
  bin/install-tools.sh
fi

# Ghostty sends TERM=xterm-ghostty, and zsh resolves terminfo while the session
# is still starting, before ~/.terminfo is consulted. Without an entry in the
# system database the line editor miscounts columns and every keystroke renders
# doubled, so install the profile's entry there once.
install_system_terminfo() {
  local term=xterm-ghostty src
  infocmp -A /usr/share/terminfo "$term" >/dev/null 2>&1 && return
  for src in "${HOME}/.nix-profile/share/terminfo" "${HOME}/.terminfo"; do
    if infocmp -A "$src" -x "$term" >/dev/null 2>&1; then
      infocmp -A "$src" -x "$term" | sudo tic -x -o /usr/share/terminfo - >/dev/null 2>&1 &&
        echo "installed $term terminfo system-wide" && return
    fi
  done
  echo "no $term terminfo source found; remote terminals may render badly" >&2
}
install_system_terminfo

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
  # script ends only once the node is on the tailnet. tailscale up prints a new
  # URL when the last one expires, so every distinct URL is printed rather than
  # only the first: an approval that arrives too late would otherwise leave the
  # run waiting on a URL nobody has seen. The wait is bounded so a guest that
  # cannot reach the control plane fails instead of hanging.
  log=$(mktemp)
  sudo tailscale up --hostname "$short" >"$log" 2>&1 &
  pid=$!
  printed=
  waited=0
  limit=${TAILSCALE_WAIT:-900}
  while kill -0 "$pid" 2>/dev/null; do
    url=$(grep -o 'https://login\.tailscale\.com/[^ ]*' "$log" | tail -1 || true)
    if [ -n "$url" ] && [ "$url" != "$printed" ]; then
      echo "approve this node in a browser:"
      echo "  $url"
      printed=$url
    fi
    if [ "$waited" -ge "$limit" ]; then
      sudo pkill -f 'tailscale up' 2>/dev/null || kill "$pid" 2>/dev/null || true
      tail -5 "$log" >&2 || true
      die "tailscale did not finish within ${limit}s. The node may register after
  this run if the URL above is still approved; otherwise re-run with
  SETUP_TAILSCALE=1 once it does, or use TS_AUTHKEY=<key>."
    fi
    sleep 1
    waited=$((waited + 1))
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

# Obsidian Sync setup: log in with the secrets file, configure the vault, run one
# sync, and record the path for obsidian-sync to read. Passwords are passed as
# arguments, so they appear in the process table for that moment.
setup_obsidian() {
  local secrets vault_path ob
  case $SECRETS_FILE in
    /*) secrets=$SECRETS_FILE ;;
    *) secrets="$DIR/$SECRETS_FILE" ;;
  esac
  [ -r "$secrets" ] || { echo "no $SECRETS_FILE; skipping obsidian" >&2; return 0; }
  # shellcheck disable=SC1090
  . "$secrets"
  if [ -z "${OBSIDIAN_EMAIL:-}" ] || [ -z "${OBSIDIAN_PASSWORD:-}" ] || [ -z "${OBSIDIAN_VAULT:-}" ]; then
    echo "OBSIDIAN_EMAIL, OBSIDIAN_PASSWORD or OBSIDIAN_VAULT unset; skipping obsidian" >&2
    return 0
  fi

  ob="$HOME/.nix-profile/bin/ob"
  [ -x "$ob" ] || { echo "ob is not installed; skipping obsidian" >&2; return 0; }

  vault_path=${OBSIDIAN_VAULT_PATH:-$HOME/vault}
  mkdir -p "$vault_path"

  # Auth and configuration are separate checks: sync-list-local answers from
  # local config even when logged out, so auth is probed against the server.
  authed=0
  "$ob" sync-list-remote --json >/dev/null 2>&1 && authed=1
  configured=0
  "$ob" sync-list-local --json 2>/dev/null |
    grep -qF "\"path\": \"$vault_path\"" && configured=1

  if [ "$authed" = 1 ] && [ "$configured" = 1 ]; then
    echo "obsidian sync already configured for $vault_path"
  else
    if [ "$authed" = 0 ]; then
      # The password is passed as an argument and is therefore visible in the
      # process table for the moment the command runs; accepted for a
      # single-user guest at home, where the alternative needs a terminal.
      if ! "$ob" login --email "$OBSIDIAN_EMAIL" --password "$OBSIDIAN_PASSWORD" >/dev/null 2>&1; then
        echo "obsidian login failed; check OBSIDIAN_EMAIL and OBSIDIAN_PASSWORD" >&2
        return 0
      fi
    fi
    if [ "$configured" = 0 ]; then
      # The vault is end-to-end encrypted, so sync-setup needs that password too.
      setup_args=(--vault "$OBSIDIAN_VAULT" --path "$vault_path" --device-name "$(hostname -s)")
      [ -n "${OBSIDIAN_E2E_PASSWORD:-}" ] && setup_args+=(--password "$OBSIDIAN_E2E_PASSWORD")
      "$ob" sync-setup "${setup_args[@]}"
    fi
  fi

  # Materialise the vault once, so the unit's condition holds.
  "$ob" sync --path "$vault_path" >/dev/null 2>&1 || true

  # The unit runs inside ~/robovault, so a different path cannot be driven
  # declaratively without passing it through the unit.
  if [ "$vault_path" != "$HOME/robovault" ]; then
    echo "obsidian-sync expects the vault at ~/robovault, not $vault_path;" >&2
    echo "set OBSIDIAN_VAULT_PATH=\$HOME/robovault or edit nix/headless.nix" >&2
  fi

  # The unit runs without a login session, so the user manager has to linger,
  # and systemd --user needs a runtime directory over a plain ssh command.
  export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  loginctl enable-linger "$(id -un)" 2>/dev/null ||
    sudo loginctl enable-linger "$(id -un)" 2>/dev/null || true
  systemctl --user enable --now obsidian-sync 2>/dev/null ||
    echo "obsidian-sync unit is not installed yet; apply the flake, then enable it" >&2
  echo "obsidian sync configured for $OBSIDIAN_VAULT at $vault_path"
}

# Repositories beyond this one, listed as "owner/name [dir]" in REPOS_FILE, where
# a "dir <path>" line sets the directory for the lines below it. Only a missing
# clone is acted on: an existing checkout is left alone, because pulling work
# repositories on every provision is not what an update means. One repository
# that will not clone is reported and does not stop the run.
clone_repos() {
  local list repo dir target current= cloned=0 present=0 failed=0
  case $REPOS_FILE in
    /*) list=$REPOS_FILE ;;
    *) list="$DIR/$REPOS_FILE" ;;
  esac
  [ -r "$list" ] || {
    echo "no $REPOS_FILE; skipping extra repositories" >&2
    return 0
  }
  while read -r repo dir _; do
    repo=${repo%%#*}
    repo=${repo//[[:space:]]/}
    [ -n "$repo" ] || continue
    # A bare "dir" line is a directive, so the four repositories that belong
    # together say where they go once instead of on every line.
    if [ "$repo" = "dir" ]; then
      current=${dir:-}
      continue
    fi
    target=${dir:-${current:-$REPO_HOME}}
    case $target in
      "~"*) target="$HOME${target#\~}" ;;
      /*) ;;
      *) target="$HOME/$target" ;;
    esac
    [ -n "${dir:-}" ] || target="$target/$(basename "$repo")"
    if [ -d "$target/.git" ]; then
      present=$((present + 1))
      continue
    fi
    mkdir -p "$(dirname "$target")"
    # gh first, because it already carries credentials for a private repository;
    # otherwise try https and then ssh, whichever the guest happens to have.
    if have gh && gh auth status >/dev/null 2>&1 && gh repo clone "$repo" "$target" >/dev/null 2>&1 ||
      git clone --quiet "https://github.com/$repo.git" "$target" >/dev/null 2>&1 ||
      git clone --quiet "git@github.com:$repo.git" "$target" >/dev/null 2>&1; then
      cloned=$((cloned + 1))
    else
      echo "could not clone $repo; check access, then: gh repo clone $repo $target" >&2
      failed=$((failed + 1))
    fi
  done <"$list"
  echo "repositories: $cloned cloned, $present already present, $failed failed"
}

# An author is what a commit needs, and it cannot go in ~/.gitconfig: that is a
# symlink into the repo. It goes in the local file the shared config includes.
# Signing and the https-to-ssh rewrite stay out on purpose: a guest's key is its
# own, and one without a key must still be able to clone over https.
setup_git_identity() {
  local file=$HOME/.gitconfig.local
  if [ -z "${GIT_NAME:-}" ] || [ -z "${GIT_EMAIL:-}" ]; then
    echo "no git author supplied; skipping" >&2
    return 0
  fi
  if [ -L "$file" ]; then
    echo "$file is a link into the repo; leaving it alone" >&2
    return 0
  fi
  if [ -f "$file" ] && grep -q '^\[user\]' "$file"; then
    echo "git author already set in $file"
    return 0
  fi
  printf '[user]\n\tname = %s\n\temail = %s\n' "$GIT_NAME" "$GIT_EMAIL" >"$file"
  echo "git author set to $GIT_NAME <$GIT_EMAIL>"
}

if [ "$SETUP_KEY" = "1" ]; then
  prepare_ssh
  setup_ssh_key
fi
[ "$SETUP_GIT" = "1" ] && setup_git_identity
[ "$SETUP_TAILSCALE" = "1" ] && join_tailnet
[ "$SETUP_GH" = "1" ] && register_git_key
[ "$SETUP_REPOS" = "1" ] && clone_repos
[ "$SETUP_OBSIDIAN" = "1" ] && setup_obsidian

case $SECRETS_FILE in
  /*) secrets_dest=$SECRETS_FILE ;;
  *) secrets_dest="$DIR/$SECRETS_FILE" ;;
esac
if [ "$SETUP_SECRETS" = "1" ] && [ ! -r "$secrets_dest" ]; then
  echo "note: $secrets_dest is missing; copy it from the workstation for the"
  echo "      agent tools to reach a provider"
fi

echo "done: $(hostname -s) is on $TARGET"
