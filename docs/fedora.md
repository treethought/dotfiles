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

## Tools with their own installer

`bin/install-tools.sh` installs the tools that sit outside Nix and dnf and keep
themselves up to date, currently polytoken. The dev VM bootstrap runs it as part
of provisioning; on the laptop run it after a fresh install, or again only if a
tool is missing.

```sh
./bin/install-tools.sh
```

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

## Desktop shell

The session is niri with DMS, both from the distro; only the configuration lives in this repo.
Appearance is split between `niri/config.kdl` (hand-written), `niri/local-overrides.kdl` (wins
over DMS output), and `dms/niri/*.kdl` (generated from the DMS settings UI and tracked). DMS
draws the wallpaper, so `swaybg` is only a fallback for when the shell is not running.

Screen colour temperature is `gammastep` from Nix, run by a user service. f.lux is not usable
here: it only ships `xflux`, which drives X11/XRandR and does nothing under Wayland. niri
exposes `zwlr-gamma-control`, which gammastep uses, and the location is auto-detected so the
temperature follows local sunset.

## Sleep and suspend

`fedora/sleep-deep.sh` switches the kernel from `s2idle` to `deep` (suspend-to-RAM / S3) and
records the choice on the kernel cmdline. Only the kernel knows about this: DMS, KDE and niri
have no setting for the sleep state, and DMS's Suspend entry simply calls logind.

Why we use it: a long `s2idle` session leaves this machine's embedded controller latched at
400 MHz on every core, and reboots do not clear it, only an EC power cycle does
(`framework-tool --reboot-ec reboot`). `s2idle` keeps the SoC powered in S0, so a suspended
laptop keeps making heat with the fan off, which is the suspected trigger. S3 powers the SoC
down and leaves only RAM refreshing. The full investigation, including the EC flash dumps, is
in the vault note "Framework laptop stuck at 400 MHz".

```sh
sudo ./fedora/sleep-deep.sh
cat /sys/power/mem_sleep   # expect [deep] s2idle
```

Hibernate stays unavailable: `/sys/power/disk` is `[disabled]` and the only swap is 8 GB of
zram, so DMS hides its Hibernate entry and the "Suspend then hibernate" option. Adding a disk
swapfile large enough for 62 GB of RAM is what that would take.

## Baseline

`fedora/baseline.txt` records the installed package baseline from
`dnf repoquery --userinstalled`. Refresh it when the baseline intentionally changes, and note
significant changes to this file first.
