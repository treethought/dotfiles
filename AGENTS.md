# Dotfiles agent guide

## Purpose

This repository is a cross-platform personal environment with shared configuration and specific per-platform modules. Keep shared configuration portable, keep secrets out of Git, and follow the package ownership documented below.

## First steps

Read `README.md`, `docs/fedora.md`, and `docs/hardware.md` for repository and machine context, and `handoff.md` for current status. Inspect the relevant module and its callers before editing. Check `git status` first, since unrelated uncommitted work may be present.

On Fedora, the primary Home Manager target is:

```sh
home-manager switch --flake ~/dotfiles#framework
```

Build without activating:

```sh
home-manager build --flake ~/dotfiles#framework
```

On the Mac, the intended target is `#mac`, but the Mac migration is not complete.

## Installation

### Applying the configuration

Clone the repository, recreate ignored private files for the machine, apply the relevant Home Manager target, and run `install.sh` for plain configuration links. The current primary target is `framework`; the Mac target is `mac`.

The installer backs up an existing destination with a timestamp before creating a symlink. It manages tmux, Starship, Neovim, Ranger, Git, Ghostty, Zellij, Crush, and PolyToken. Home Manager, not `install.sh`, manages `~/.zshrc`.

### Fedora system prerequisites

The repo does not manage root-owned system state. The Fedora host setup includes:

- Fedora KDE and Framework firmware updates.
- RPM Fusion, codecs, `ffmpeg`, and Intel media drivers.
- zsh, Ghostty from the `scottames/ghostty` COPR, and Tailscale.
- Snapper and Btrfs Assistant for root and home snapshots.
- A separate `/nix` Btrfs subvolume.
- PipeWire, Bluetooth, hardware, SELinux, system services, and Homebrew's Fedora build prerequisites.

See `docs/fedora.md` and `docs/hardware.md` for machine-specific details. Power management is provided by Fedora's `tuned`/`tuned-ppd` setup.

## Package ownership

Use the smallest appropriate ownership boundary:

| Software | Source | File or command |
| --- | --- | --- |
| Shared CLI tools, languages, fonts, shell integrations | Nix/Home Manager | `nix/packages.nix`, `nix/zsh.nix` |
| NUR packages | Nix/Home Manager | `nix/packages.nix`, currently Crush |
| Flatpak desktop apps | Flathub through nix-flatpak | `nix/flatpak.nix` |
| PipeWire / WirePlumber configuration | Nix/Home Manager | `nix/audio.nix` |
| Fedora drivers, codecs, system services, audio engines, terminal, and native build toolchain | dnf or vendor/COPR repo | manual Fedora setup |
| macOS GUI apps | Homebrew | `Brewfile` |
| Secrets and per-machine overrides | ignored local files | `private/`, `*.private` |

The package boundaries are intentional: terminal and host-integrated tools use Nix or the system package manager, while desktop applications use Flatpak where appropriate. Keep a plugin host and its plugins from the same package ecosystem when ABI compatibility matters.

### Adding Nix packages

Add a package to `nix/packages.nix`, then use the normal build and switch workflow. Small custom binary packages can be defined in a local `let` there with pinned versions and hashes.

`librepods` and the pinned `ntn` Notion CLI are currently managed this way.

### Adding Flatpaks

Add the exact Flathub application ID to `nix/flatpak.nix`, then switch. Refresh KDE's application cache if an installed icon does not appear:

```sh
kbuildsycoca6 --noincremental
```

### System packages

Root-owned system software is maintained separately from Home Manager. Record significant changes in `docs/fedora.md` or `docs/hardware.md`, and update `fedora/baseline.txt` when the installed baseline changes.

### Homebrew

`Brewfile` remains the reference for the Mac target. On the current machine, Linuxbrew is installed separately for private internal tools; its Fedora prerequisites are the `development-tools` group plus `procps-ng`, `curl`, and `file`. Most portable CLI tools remain Nix-managed.

## Nix and Home Manager rules

- `flake.nix` defines `framework` for `x86_64-linux` and `mac` for `aarch64-darwin`.
- `nix/common.nix` imports shared packages and zsh behavior.
- `nix/linux.nix` contains Fedora-only Home Manager settings.
- `nix/darwin.nix` contains Mac-only settings.
- `nix/flatpak.nix` manages Flathub apps on Linux.
- `nix/audio.nix` manages the PipeWire config files and the internal-mic reset unit. It does not install the engine.
- `flake.lock` pins inputs and should change when inputs are intentionally updated.
- A new file referenced by a flake must be staged or intent-to-added before evaluation because flakes only see Git-tracked files.
- `home.stateVersion` records the module compatibility baseline and is changed deliberately.
- `~/.zshrc` is generated and read-only. Put shell behavior in `nix/zsh.nix`, not by appending to the generated file.
- Credentials, API keys, private paths, and machine-specific identity belong in ignored local files rather than the Nix store or repository.

After changing Nix code, run the narrowest build first, then the switch. If a build fails, fix the first failure before making unrelated edits. Build logs are useful with:

```sh
nix log /nix/store/<derivation>.drv
```

## Configuration links

`install.sh` creates links for:

- `tmux/tmux.conf` -> `~/.tmux.conf`
- `starship/starship.toml` -> `~/.config/starship.toml`
- Neovim, Ranger, Ghostty, Zellij, Git, Crush, and PolyToken config paths

When adding a managed file, update `install.sh` and test it on a non-conflicting path. Preserve the backup behavior.

## Audio

Nix owns the audio configuration; dnf owns the engine. `nix/audio.nix` writes
`~/.config/pipewire/pipewire.conf.d/` and a systemd user unit, while PipeWire, WirePlumber,
`rtkit`, `pipewire-jack`, and any DAW or plugin come from dnf. Keep it that way: a plugin host
and its plugins must share one glibc, and the engine needs root-owned realtime setup.

The internal mic has a known +30 dB preamp boost that sits outside WirePlumber's volume
model and clips the ADC, so input level runs hot and distorted no matter what the desktop
slider says. `nix/audio.nix` zeroes that control at login. `docs/hardware.md` has the control
numbers and how to measure the real signal with `pw-record` and `ffmpeg astats`. Do not
diagnose input gain from a mixer GUI alone; those sliders do not show every gain stage.

Hardware notes: the USB interface is a Universal Audio Volt 2 (card `V2`, 44.1-192 kHz). It
has no software mixer, so input gain is the physical knob, and with nothing plugged into an
input it still appears as a source reading about `-76 dBFS`, silence that is easy to mistake
for a working device. Always confirm the default source is the input actually in use and that
a connected interface has something attached.

## AirPods and Bluetooth

The current repo installs `librepods` through Nix as an AirPods utility. Hailey's MagicPods fork remains a possible future option, but it is not part of the current configuration.

Bluetooth and PipeWire are system/session concerns, not ordinary Nix packages. Diagnose them with:

```sh
bluetoothctl show
bluetoothctl devices
bluetoothctl info <MAC>
pactl list short cards
systemctl --user status pipewire pipewire-pulse wireplumber
```

Avoid changing `/etc/bluetooth/main.conf` or system services automatically. Such changes require explicit manual documentation and should be reversible.

## Git and documentation

Keep documentation synchronized with actual files, especially package lists and installation commands. Make repository changes without committing or pushing unless explicitly requested.
