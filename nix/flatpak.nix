# GUI apps from Flathub, installed per-user by nix-flatpak on switch.
{ ... }:
{
  services.flatpak = {
    enable = true;
    packages = [
      "md.obsidian.Obsidian"
      "com.discordapp.Discord"
      "com.bitwarden.desktop"
      "org.jeffvli.feishin"
      "com.slack.Slack"
      "com.spotify.Client"
      "org.signal.Signal"

      # Audio: levels, routing, DSP
      "com.saivert.pwvucontrol" # PipeWire mixer with live input/output meters
    ];
    update.auto.enable = true; # weekly background updates
  };
}
