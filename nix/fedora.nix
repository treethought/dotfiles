# Fedora integration, shared by the laptop and the dev VMs. Only what depends on
# the distro living outside Nix: where the home directory is, and the fixes Nix
# programs need when /usr belongs to dnf.
{ pkgs, ... }:
{
  home.homeDirectory = "/home/treethought";

  # Non-NixOS integration: adds Nix paths to XDG_DATA_DIRS for the session
  # (so Nix apps show in the app menu), terminfo/locale fixes for Nix
  # programs, and GPU support for Nix GUI apps. If a switch warns
  # "not yet set up to use the GPU", run the sudo .../non-nixos-gpu-setup
  # command it prints.
  targets.genericLinux.enable = true;

  # Sessions from Ghostty arrive with TERM=xterm-ghostty. ncurses searches
  # ~/.terminfo by default, so linking the entry there is enough, and it avoids
  # TERMINFO/TERMINFO_DIRS: exporting those during shell startup makes zsh look
  # the entry up before the variable has taken effect, which is what produced
  # "can't find terminal definition" and a line editor that doubled keystrokes.
  home.file.".terminfo" = {
    source = "${pkgs.ghostty.terminfo}/share/terminfo";
    recursive = true;
  };
}
