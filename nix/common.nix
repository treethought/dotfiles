# Shared by Linux and macOS. Entry point that pulls in the other modules.
#   packages.nix  - everything installed (CLI tools, languages, fonts)
#   zsh.nix       - shell behaviour
#   linux.nix / darwin.nix - per-OS bits (added by flake.nix)
{ ... }:
{
  imports = [
    ./packages.nix
    ./zsh.nix
  ];

  home.username = "treethought";
  home.stateVersion = "25.05"; # set once, don't bump later

  programs.home-manager.enable = true;

  # Environment for the whole login session (not just zsh)
  home.sessionVariables = {
    EDITOR = "nvim";
    DOTFILES = "$HOME/dotfiles";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];

  fonts.fontconfig.enable = true;
}
