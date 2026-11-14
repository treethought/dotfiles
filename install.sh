#!/usr/bin/env sh

set -eu

# DOTFILES points to the repository so configs can refer back to sibling files.
DOTFILES=${DOTFILES:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}

backup_path() {
	destination=$1
	backup="$destination.backup-$(date +%Y%m%d%H%M%S)"
	mv "$destination" "$backup"
	printf 'Backed up %s to %s\n' "$destination" "$backup"
}

link_file() {
	source=$1
	destination=$2

	# Some linked paths live in the ignored private/ tree or are otherwise
	# absent on a fresh clone.
	if [ ! -e "$DOTFILES/$source" ]; then
		printf 'Skipped %s (no %s)\n' "$destination" "$source"
		return 0
	fi

	mkdir -p "$(dirname "$destination")"

	if [ -L "$destination" ]; then
		current=$(readlink "$destination")
		if [ "$current" = "$DOTFILES/$source" ]; then
			return
		fi
		backup_path "$destination"
	elif [ -e "$destination" ]; then
		backup_path "$destination"
	fi

	ln -s "$DOTFILES/$source" "$destination"
	printf 'Linked %s to %s\n' "$destination" "$DOTFILES/$source"
}

# Zsh is managed by Home Manager (nix/zsh.nix), which writes ~/.zshrc.
# zsh/zshrc is kept only for machines not yet on Home Manager.

# Tmux
link_file tmux/tmux.conf "$HOME/.tmux.conf"

# Starship
link_file starship/starship.toml "$HOME/.config/starship.toml"

# Neovim
link_file nvim/init.lua "$HOME/.config/nvim/init.lua"
link_file nvim/lua "$HOME/.config/nvim/lua"

# Ranger
link_file ranger/rc.conf "$HOME/.config/ranger/rc.conf"
link_file ranger/scope.sh "$HOME/.config/ranger/scope.sh"
link_file ranger/commands.py "$HOME/.config/ranger/commands.py"
link_file ranger/colorschemes "$HOME/.config/ranger/colorschemes"

# Git
link_file git/gitconfig "$HOME/.gitconfig"
link_file git/gitignore_global "$HOME/.gitignore_global"
link_file git/gitconfig.local.private "$HOME/.gitconfig.local"

# Ghostty
link_file ghostty/config.ghostty "$HOME/.config/ghostty/config.ghostty"

# Niri
link_file niri/config.kdl "$HOME/.config/niri/config.kdl"
link_file niri/niri-portals.conf "$HOME/.config/xdg-desktop-portal/niri-portals.conf"

# DMS (Quickshell shell that draws the bar and generates niri/dms/*.kdl).
# settings.json is the UI state; dms/niri/ is the compositor config it writes.
# DMS writes through these symlinks, so UI changes land in the repo.
link_file dms/settings.json "$HOME/.config/dms/settings.json"
link_file dms/niri "$HOME/.config/niri/dms"

# Zellij
link_file zellij/config.kdl "$HOME/.config/zellij/config.kdl"
link_file zellij/scripts/session-picker.sh "$HOME/.config/zellij/scripts/session-picker.sh"

# Crush
link_file crush/crush.json "$HOME/.config/crush/crush.json"
link_file crush/hooks/deny-dangerous.sh "$HOME/.config/crush/hooks/deny-dangerous.sh"

# PolyToken
link_file polytoken/config.yaml "$HOME/.config/polytoken/config.yaml"

# OpenCode (package commented out in nix/packages.nix)
# link_file opencode/config.json "$HOME/.config/opencode/opencode.json"

# Roast: credentials come from AGW_API_KEY, so this config is tracked
link_file roast/config.yaml "$HOME/.config/roast/config.yaml"

printf 'Linked dotfiles from %s\n' "$DOTFILES"
