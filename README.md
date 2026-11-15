# Dotfiles

Personal cross-platform shell, editor, terminal, and development configuration. Shared settings live alongside specific per-platform modules and package sources.

## Start here

- `AGENTS.md`: repository conventions, configuration ownership, workflows, and machine context.
- `docs/`: host setup for the Linux machines, Proxmox guest provisioning, and hardware notes, including the PipeWire configuration used for audio work.
- `flake.nix`: Home Manager targets.
- `nix/`: Nix packages and platform modules.
- `install.sh`: links plain configuration files into their runtime locations.
- `Brewfile`: GUI application reference for the Mac target.

## Setup

Clone the repository, recreate ignored private files for the machine, apply the relevant Home Manager target, and run `install.sh` for plain configuration links.

```sh
git clone git@github.com:treethought/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./install.sh
```

The current primary Home Manager target is `framework`; `mac` and `devbox` are the secondary targets, the latter for a headless Fedora VM:

```sh
home-manager switch --flake ~/dotfiles#framework
home-manager switch --flake ~/dotfiles#mac
home-manager switch --flake ~/dotfiles#devbox
```

## Updating

Three layers, in order: this repository's configuration, the tools it installs outside Nix, then the
host's own packages.

```sh
# configuration from this repo
home-manager switch --flake ~/dotfiles#framework
./install.sh                          # only when the set of linked paths changed
bin/install-tools.sh                  # polytoken, roast

# newer packages, when you want them: commit the updated flake.lock afterwards
nix flake update && home-manager switch --flake ~/dotfiles#framework

# the Fedora host itself
sudo dnf upgrade --refresh
fwupdmgr refresh --force && fwupdmgr update      # Framework firmware
```

Flatpak applications update weekly on their own (`nix/flatpak.nix`), so they need no step here.
Linked files (nvim, zellij, git, crush) apply as soon as the checkout changes; only Nix changes need
the switch.

Guests are updated with one command, which pulls, switches, relinks, and installs tools in a single
run:

```sh
./proxmox/update-devbox.sh devbox          # add --git/--repos/--agents/--secrets when needed
```

`docs/fedora.md` has the host-side details and `proxmox/README.md` the guest ones.

## Configuration ownership

| Area | Location |
| --- | --- |
| Portable user packages and shell integrations | `nix/packages.nix`, `nix/zsh.nix` |
| Shared and platform-specific Home Manager settings | `nix/common.nix`, `nix/fedora.nix`, `nix/darwin.nix` |
| Desktop-only modules (needs a display) | `nix/desktop.nix`, `nix/fonts.nix`, `nix/audio.nix` |
| Linux desktop applications | `nix/flatpak.nix` |
| PipeWire / WirePlumber configuration | `nix/audio.nix` |
| Niri compositor and DMS desktop appearance | `niri/`, `dms/`, `install.sh` |
| Plain editor, terminal, multiplexer, Git, and tool configuration | Individual directories and `install.sh` |
| Mac GUI application reference | `Brewfile` |
| Secrets and machine-specific overrides | Ignored `private/` and `*.private` files |

See `AGENTS.md` for the detailed operating context and maintenance patterns.
