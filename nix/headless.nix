# Tools that only make sense without a display, so guests get them and the laptop
# does not. Imported by the devbox target alone.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Headless Obsidian Sync client, so a guest can read the vault without a GUI.
    # It is a separate client to the Flatpak app on the laptop: authenticate it
    # once with `ob login`, and do not point two clients at one vault on one host.
    obsidian-headless
  ];
}
