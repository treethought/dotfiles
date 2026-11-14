# Everything that needs a display. The laptop imports this; a headless guest
# composes common + fedora and gets none of it. GUI applications come from
# Flatpak (nix/flatpak.nix); the audio engine and system services come from dnf.
{ pkgs, ... }:
{
  imports = [
    ./audio.nix
    ./flatpak.nix
    ./fonts.nix
  ];

  home.packages = with pkgs; [
    firefoxpwa
    librepods
    helm # polyphonic synthesizer
    wl-clipboard # wl-copy / wl-paste (replaces pbcopy in tmux)

    # niri session. Wayland-only, so they stay out of packages.nix.
    swaylock # screen lock, bound to Super+Alt+L
    # Not in use: DMS renders the wallpaper on its own layer, and nothing
    # spawns swaybg. Kept only as a fallback for when the shell is not up.
    swaybg
    mako # notification daemon, dbus-activated so no autostart needed
    brightnessctl # backlight keys, needs the udev rule + video group
    gammastep # screen colour temperature via zwlr-gamma-control (f.lux equivalent)
  ];

  # Fedora's Firefox scans /usr/lib{,64}/mozilla/native-messaging-hosts and
  # ~/.mozilla/native-messaging-hosts, never the Nix profile, so the PWA helper
  # stays invisible to the extension until its manifest is linked here.
  home.file.".mozilla/native-messaging-hosts/firefoxpwa.json".source =
    "${pkgs.firefoxpwa}/lib/mozilla/native-messaging-hosts/firefoxpwa.json";

  # f.lux is not an option here: the Linux build ships as xflux, a closed-source
  # binary that talks X11/XRandR only, so it does nothing under Wayland, and it
  # has no nixpkgs package to pin. gammastep is the Wayland equivalent and talks
  # zwlr-gamma-control, which niri exposes. Location is auto-detected, so the
  # temperature follows sunset.
  systemd.user.services.gammastep = {
    Unit = {
      Description = "Screen colour temperature (gammastep)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.gammastep}/bin/gammastep -t 6500:3500";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
