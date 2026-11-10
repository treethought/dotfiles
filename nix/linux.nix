# Fedora-only bits.
# GUI apps come from Flatpak (nix/flatpak.nix); system/audio stuff from dnf.
{ pkgs, ... }:
{
  imports = [
    ./audio.nix
    ./flatpak.nix
  ];

  home.homeDirectory = "/home/treethought";

  # Non-NixOS integration: adds Nix paths to XDG_DATA_DIRS for the session
  # (so Nix apps show in the app menu), terminfo/locale fixes for Nix
  # programs, and GPU support for Nix GUI apps. If a switch warns
  # "not yet set up to use the GPU", run the sudo .../non-nixos-gpu-setup
  # command it prints.
  targets.genericLinux.enable = true;

  home.packages = with pkgs; [
    wl-clipboard # wl-copy / wl-paste (replaces pbcopy in tmux)

    # niri session. These are Wayland/Linux-only, so they stay out of the
    # shared packages.nix that the Mac target also imports.
    swaylock # screen lock, bound to Super+Alt+L
    swaybg # wallpaper, needs a spawn-at-startup to do anything
    mako # notification daemon, dbus-activated so no autostart needed
    brightnessctl # backlight keys, needs the udev rule + video group
  ];
}
