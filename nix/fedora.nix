# Fedora integration, shared by the laptop and the dev VMs. Only what depends on
# the distro living outside Nix: where the home directory is, and the fixes Nix
# programs need when /usr belongs to dnf.
{ config, ... }:
{
  home.homeDirectory = "/home/treethought";

  # Non-NixOS integration: adds Nix paths to XDG_DATA_DIRS for the session
  # (so Nix apps show in the app menu), terminfo/locale fixes for Nix
  # programs, and GPU support for Nix GUI apps. If a switch warns
  # "not yet set up to use the GPU", run the sudo .../non-nixos-gpu-setup
  # command it prints.
  targets.genericLinux.enable = true;

  # genericLinux exports TERMINFO_DIRS through the systemd user session, which a
  # plain SSH login never sees. Without it ncurses cannot find terminfo the Nix
  # profile ships, so a terminal like Ghostty's has no key bindings (backspace
  # among them) and readline misbehaves.
  home.sessionVariables.TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/usr/share/terminfo:/lib/terminfo:/etc/terminfo";
}
