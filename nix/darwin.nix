# macOS-only bits. Keep Homebrew for casks (GUI apps) for now.
{ ... }:
{
  home.homeDirectory = "/Users/treethought";

  # was zsh/paths.zsh: Ghostty's CLI lives inside the app bundle
  home.sessionPath = [ "/Applications/Ghostty.app/Contents/MacOS" ];
}
