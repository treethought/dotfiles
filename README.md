# Dotfiles

## Install

The setup uses explicit symlinks. Existing files are backed up with a timestamp
before they are replaced.

```sh
git clone git@github.com:treethought/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./install-omz.sh
./install.sh
exec zsh
```

If the repository is elsewhere, set `DOTFILES` before running the installer:

```sh
export DOTFILES="$HOME/path/to/dotfiles"
cd "$DOTFILES"
./install-omz.sh
./install.sh
```

`install-omz.sh` installs Oh My Zsh and the three custom plugins used by
`zsh/zshrc`. It does not replace existing installations.

`install.sh` links the managed configuration files into their expected
locations. The shell config sources `zsh/paths.zsh` from the repository and
optionally loads private overrides.

## Private files

Files under `private/` are ignored by Git. They hold secrets, work packages,
and machine-specific shell settings.

```sh
mkdir -p private
chmod 700 private
$EDITOR private/secrets.zsh
chmod 600 private/secrets.zsh
```

The optional files currently used are:

```text
private/secrets.zsh
zsh/paths.zsh.private
Brewfile.private
```

## Packages

```sh
brew bundle --file Brewfile
[ ! -f Brewfile.private ] || brew bundle --file Brewfile.private
```

## Managed locations

The installer manages Zsh, tmux, Starship, Neovim, Ranger, Git, Ghostty,
Zellij, Crush, and PolyToken.
