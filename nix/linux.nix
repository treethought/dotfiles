# Fedora-only bits.
# GUI apps (ghostty, bitwarden, ipfs-desktop) come from dnf/COPR or Flathub, not Nix:
# Nix GUI apps on non-NixOS often have OpenGL/driver issues.
{ pkgs, ... }:
{
  home.homeDirectory = "/home/treethought";

  # Non-NixOS integration: adds Nix paths to XDG_DATA_DIRS for the session
  # (so Nix apps show in the app menu) and GPU support for Nix GUI apps.
  targets.genericLinux.enable = true;

  home.packages = with pkgs; [
    wl-clipboard # wl-copy / wl-paste (replaces pbcopy in tmux)
  ];
}
