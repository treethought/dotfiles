# Fonts are only useful where text is rendered, so the desktop targets import
# this and the headless target does not. Nothing on a server draws glyphs.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    inter
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.hack
    nerd-fonts.caskaydia-cove
    nerd-fonts.caskaydia-mono
    nerd-fonts.commit-mono
    nerd-fonts.meslo-lg
    nerd-fonts.ubuntu-mono
    nerd-fonts.inconsolata-go
    nerd-fonts._0xproto
    nerd-fonts.monofur
    nerd-fonts.overpass
  ];
}
