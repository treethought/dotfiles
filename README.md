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

Each layer owns a different thing and they are applied in this order.

### Repository changes

On the machine where you edit, the files are already in place. Anywhere else, pull first.

```sh
git pull --ff-only                      # on a machine that is not where you edit
home-manager switch --flake ~/dotfiles#framework
./install.sh                            # only when the set of linked paths changed
bin/install-tools.sh                    # polytoken, roast
```

Linked files (nvim, zellij, git, crush) take effect as soon as the checkout changes, because they are
symlinks into it; only Nix changes need the switch. `home-manager generations` lists the previous
generations and `home-manager --rollback` returns to the last one.

### Nix packages

`nix flake update` moves the pinned inputs; the switch rebuilds from them, and `flake.lock` records
the result, so commit it and every other machine builds the same versions.

```sh
nix flake update                        # or: nix flake update nixpkgs, for one input
home-manager switch --flake ~/dotfiles#framework
git add flake.lock && git commit -m "update flake inputs"
```

### The Fedora host

Root-owned packages are dnf's business, not Home Manager's:

```sh
sudo dnf upgrade --refresh
fwupdmgr refresh --force && fwupdmgr update      # Framework firmware
```

Flatpak applications update weekly by themselves (`nix/flatpak.nix`). `docs/fedora.md` has the
host-side detail, including when a reboot is needed.

### Guests

One command pulls, switches, relinks, and installs tools:

```sh
./proxmox/update-devbox.sh devbox          # --git/--repos/--agents/--secrets as needed
./proxmox/update-devbox.sh devbox --dnf    # also upgrade the guest's Fedora packages
```

A guest's kernel only changes with `--dnf`, and a new kernel needs a reboot before it is running.
`proxmox/README.md` has the rest.

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
