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

  # obsidian-sync runs inside the vault, so no path is passed on the command
  # line and `ob` keeps its own state under ~/.config. The condition keeps the
  # unit inactive until a vault exists, and the bootstrap only enables it after
  # setup succeeds.
  systemd.user.services.obsidian-sync = {
    Unit = {
      Description = "Obsidian Sync (headless)";
      After = [ "network-online.target" ];
      ConditionPathExists = "%h/robovault";
    };
    Service = {
      WorkingDirectory = "%h/robovault";
      ExecStart = "${pkgs.obsidian-headless}/bin/ob sync --continuous";
      Restart = "on-failure";
      RestartSec = 30;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
