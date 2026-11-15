# Fedora integration, shared by the laptop and the dev VMs. Only what depends on
# the distro living outside Nix: where the home directory is, and the fixes Nix
# programs need when /usr belongs to dnf.
{ config, pkgs, ... }:
{
  home.homeDirectory = "/home/treethought";

  # Non-NixOS integration: adds Nix paths to XDG_DATA_DIRS for the session
  # (so Nix apps show in the app menu), terminfo/locale fixes for Nix
  # programs, and GPU support for Nix GUI apps. If a switch warns
  # "not yet set up to use the GPU", run the sudo .../non-nixos-gpu-setup
  # command it prints.
  targets.genericLinux.enable = true;

  # Sessions from Ghostty arrive with TERM=xterm-ghostty, which needs an entry on
  # the host being connected to, or zsh and readline lose key bindings such as
  # backspace. Placing it in ~/.terminfo means ncurses finds it without any
  # environment variable, which matters because lookup happens while the session
  # variables are still being set.
  home.file.".terminfo" = {
    source = "${pkgs.ghostty.terminfo}/share/terminfo";
    recursive = true;
  };

  # genericLinux exports this through the systemd user session only, which an SSH
  # login never sees, so the profile's terminfo would otherwise be invisible.
  home.sessionVariables.TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/usr/share/terminfo:/lib/terminfo:/etc/terminfo";
}
