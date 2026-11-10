# Fedora host

Fedora 45 KDE Plasma on the Framework 13. Everything root-owned lives here rather than in
Home Manager: drivers, codecs, system services, the PipeWire engine, and the package baseline.
Hardware specifics (including the internal mic gain quirk) are in `hardware.md`.

## System prerequisites

- Fedora KDE on a single Btrfs pool: `root` and `home` subvolumes, plus a separate `/nix`
  subvolume so the Nix store does not land in snapshots.
- RPM Fusion, codecs, `ffmpeg`, and the Intel media drivers.
- zsh; Ghostty from the `scottames/ghostty` COPR; Tailscale.
- Snapper and Btrfs Assistant covering root and home.
- The PipeWire stack: `pipewire`, `pipewire-pulse`, `pipewire-jack-audio-connection-kit`,
  `wireplumber`. `rtkit` provides realtime scheduling for audio clients.
- `tuned` / `tuned-ppd` for power management.
- Linuxbrew prerequisites, if Homebrew is used at all: the `development-tools` group plus
  `procps-ng`, `curl`, and `file`. Most portable CLI tools stay in Nix.

## Manual steps that need root

- `/etc/bluetooth/main.conf`: `DeviceID = bluetooth:004C:0000:0000` under `[General]`. Then
  restart `bluetooth` and the PipeWire stack, and remove and re-pair the AirPods:

  ```sh
  systemctl restart bluetooth
  systemctl --user restart pipewire pipewire-pulse wireplumber
  ```

- GPU setup for Nix-built GUI apps: run the `non-nixos-gpu-setup` command Home Manager prints
  when a switch warns that the user is "not yet set up to use the GPU".

- The internal mic preamp boost, if the reset unit from `nix/audio.nix` is ever removed:

  ```sh
  amixer -c PCH cset numid=9 0
  ```

## Audio ownership

The engine is dnf's business and the configuration is Nix's. `nix/audio.nix` owns
`~/.config/pipewire/pipewire.conf.d/` (sample rate, allowed rates, quantum) and the
internal-mic reset unit. Low-latency work relies on `rtkit`, which Fedora enables by default,
plus `pipewire-jack` so JACK clients can connect.

Hosts and plugins install with dnf rather than Nix so a plugin host and its plugins share one
glibc: Carla, Bitwig, SuperCollider, and the plugin set. Nix may still own their config files,
for example SuperCollider's `startup.scd`.

## Baseline

`fedora/baseline.txt` records the installed package baseline from
`dnf repoquery --userinstalled`. Refresh it when the baseline intentionally changes, and note
significant changes to this file first.
