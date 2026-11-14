# PipeWire / WirePlumber configuration.
# The engine itself (pipewire, pipewire-pulse, wireplumber, rtkit) comes from
# dnf; Nix owns only the config files.
{ pkgs, ... }:
{
  xdg.configFile = {
    # Graph-wide defaults. Only allowed-rates departs from upstream; the rest is
    # written out to document the knobs, with notes on when to change them.
    "pipewire/pipewire.conf.d/10-clock.conf".text = ''
      context.properties = {
          default.clock.rate          = 48000
          # Volt 2 rates only: 44.1, 48, 88.2, 96, 176.4, 192 kHz
          default.clock.allowed-rates = [ 44100 48000 88200 96000 176400 192000 ]

          # Quantum is the graph's processing buffer, measured in frames, not a
          # latency figure. PipeWire wakes every cycle and processes that many
          # samples per node, so the cycle time is quantum / sample rate:
          # 1024 frames is 21.3 ms at 48 kHz, 256 is 5.3 ms, 64 is 1.3 ms.
          # Round-trip latency is a multiple of this (more buffers in flight),
          # and smaller means lower latency, more CPU wakeups, and a higher
          # chance of xruns, which are audible clicks. Left at the default.
          # Adjust downward only while tracking: watch the ERR column in
          # `pw-top`, or try it for one session with
          # `pw-metadata -n settings 0 clock.force-quantum 128`.
          default.clock.quantum       = 1024
          # Floor a client may request. A DAW can still ask for 32 frames while
          # the desktop idles at 1024, so this does not need lowering first.
          default.clock.min-quantum   = 32
          # Ceiling for clients wanting large buffers. quantum-limit caps it.
          default.clock.max-quantum   = 2048
      }
    '';
  };

  # The Framework's internal mic keeps +30 dB of preamp boost on top of a maxed
  # capture gain, which drives the ADC into a square wave, so the input clips
  # instead of tracking level. It is not part of WirePlumber's volume model, so
  # it never shows up in a mixer GUI and has to be reset by control.
  # Remove this unit if a future codec default is sane.
  systemd.user.services.internal-mic-boost = {
    Unit = {
      Description = "Zero the Framework internal mic preamp boost";
      After = [ "wireplumber.service" ];
      Wants = [ "wireplumber.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'for _ in {1..30}; do ${pkgs.alsa-utils}/bin/amixer -c PCH cget numid=9 >/dev/null 2>&1 && break; sleep 1; done; ${pkgs.alsa-utils}/bin/amixer -c PCH cset numid=9 0'";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
