# Hardware

Machine-specific details for the primary laptop. Fedora setup is in `fedora.md`.

## Framework 13 (12th Gen Intel Core)

DMI reports `Laptop (12th Gen Intel Core)` with board version `A6`.

## Audio

Two ALSA cards, both driven through PipeWire:

| Card | ID | Driver | What |
| --- | --- | --- | --- |
| 0 | `PCH` | `snd_hda_intel` + `snd_hda_codec_idt` | Internal speakers, headphones, internal mic array |
| 1 | `V2` | `snd_usb_audio` | Universal Audio Volt 2 (`2b5a:0021`), USB Audio Class 2 |

### Internal mic gain quirk

The codec amplifies the internal mic twice, and both stages default to maximum:

| Control | numid | Range | At max |
| --- | --- | --- | --- |
| `Capture Volume` | 6 | 0-46, -16 dB min, 1 dB steps | +30 dB |
| `Internal Mic Boost Volume` | 9 | 0-3, 10 dB steps | +30 dB |

Together that is +60 dB into the ADC, which clips. Recorded at the default settings the
signal measured peak `0.0 dBFS`, RMS `-0.47 dB`, and `flat factor 42`, a square wave, so
anything capturing this input gets distortion instead of level. Playback is unaffected,
which makes it look like a downstream or app problem rather than a gain problem.

`nix/audio.nix` installs a systemd user unit that zeroes numid 9 at login. WirePlumber only
manages `Capture Volume`, so the preamp boost is outside its volume model and never appears
in a mixer GUI. `pwvucontrol` and friends show the node at 100% / 0.00 dB while the boost sits
on top of it.

This card also cannot resolve mixer controls by name, so `amixer` has to use numids:

```sh
amixer -c PCH cget numid=9        # Internal Mic Boost Volume
amixer -c PCH cset numid=9 0
amixer -c PCH cget numid=6        # Capture Volume
```

The source node reports `Base Volume: 10%`, so anywhere above that PipeWire leaves the ADC at
maximum and attenuates in software. Adjust the hardware control directly when noise headroom
matters; pulling the desktop slider down mostly scales an already-hot signal.

Measure the real signal instead of trusting the sliders:

```sh
pw-record --target alsa_input.pci-0000_00_1f.3.analog-stereo /tmp/t.wav
ffmpeg -i /tmp/t.wav -af astats -f null -
```

`flat factor` above zero plus peaks at `0.0 dBFS` means clipping.

### Volt 2

Universal Audio Volt 2 (`2b5a:0021`), the USB audio interface. Card `V2`, driven by
`snd_usb_audio`, USB Audio Class 2. It supports 44.1, 48, 88.2, 96, 176.4 and 192 kHz, and
`nix/audio.nix` lists exactly those as `default.clock.allowed-rates` so it never gets
resampled. Playback is one stereo device (S32_LE, 2 ch). Capture is split by UCM into two
independent mono sources, `Mic1` and `Mic2`.

It exposes no software mixer controls, so input gain is the physical knob. With no mic
attached both inputs still appear as sources and read about `-76 dBFS`, which means it can
quietly become the default input while hearing nothing. Confirm a mic is plugged into the
input before blaming PipeWire for a quiet recording.

## Bluetooth

AirPods Pro 2 are paired and managed by `librepods` (`nix/packages.nix`). `/etc/bluetooth/main.conf`
sets `DeviceID = bluetooth:004C:0000:0000` so the host identifies as an Apple device, which is
what unlocks the higher-quality mic path. See `fedora.md` for the restart and re-pair steps.
