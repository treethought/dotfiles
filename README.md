# Dotfiles

Personal cross-platform shell, editor, terminal, and development configuration. Shared settings live alongside specific per-platform modules and package sources.

## Start here

- `AGENTS.md`: repository conventions, configuration ownership, workflows, and machine context.
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

The current primary Home Manager target is `framework`; `mac` is the platform-specific secondary target:

```sh
home-manager switch --flake ~/dotfiles#framework
home-manager switch --flake ~/dotfiles#mac
```

## Configuration ownership

| Area | Location |
| --- | --- |
| Portable user packages, fonts, and shell integrations | `nix/packages.nix`, `nix/zsh.nix` |
| Shared and platform-specific Home Manager settings | `nix/common.nix`, `nix/linux.nix`, `nix/darwin.nix` |
| Linux desktop applications | `nix/flatpak.nix` |
| Plain editor, terminal, multiplexer, Git, and tool configuration | Individual directories and `install.sh` |
| Mac GUI application reference | `Brewfile` |
| Secrets and machine-specific overrides | Ignored `private/` and `*.private` files |

See `AGENTS.md` for the detailed operating context and maintenance patterns.
