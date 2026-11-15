# Nix modules

Each file is one capability; machines are composed from them in `flake.nix`.

## Modules

| File | Adds | Imported by |
| --- | --- | --- |
| `common.nix` | username, state version, session variables, and the two modules below | every target |
| `packages.nix` | CLI, language, and agent tooling | `common.nix` |
| `zsh.nix` | shell behaviour, generates `~/.zshrc` | `common.nix` |
| `fedora.nix` | Fedora integration: home directory, terminfo/locale fixes, XDG paths | `framework`, `devbox` |
| `darwin.nix` | macOS integration: home directory, Ghostty CLI path, fonts | `mac` |
| `desktop.nix` | anything needing a display: Wayland tools, browser and AirPods helpers, colour temperature | `framework` |
| `audio.nix` | PipeWire config files and the internal-mic reset unit | `desktop.nix` |
| `flatpak.nix` | Flathub applications | `desktop.nix` |
| `fonts.nix` | font packages | `desktop.nix` |
| `ops.nix` | cloud and cluster tooling (argocd, pulumi, awscli2, kubectl, k9s, kubernetes-helm); heavy, and argocd is not cached for the current pin | `framework` |
| `headless.nix` | tools that only make sense without a display, such as the headless Obsidian Sync client | `devbox` |

## Targets

```
framework = common + fedora + desktop + ops   (plus the nix-flatpak module)
devbox    = common + fedora + headless
mac       = common + darwin
```

## Where a new package goes

- Usable from a terminal anywhere (CLI tools, languages, `mosh`, `rsync`): `packages.nix`
- Needs a display, sound, or a desktop session: `desktop.nix`
- Needs root, a distro path, or distro integration: `fedora.nix`, `darwin.nix`, or dnf/Homebrew
- Heavy tooling only one machine needs: `ops.nix` (or another role module), not `packages.nix`
- A GUI application that ships as Flatpak: `flatpak.nix`

## Adding a target

Add an entry under `homeConfigurations` in `flake.nix` and list the modules it sums.
