#!/usr/bin/env sh

set -eu

zsh_dir="${ZSH:-$HOME/.oh-my-zsh}"
custom_dir="${ZSH_CUSTOM:-$zsh_dir/custom}"

if [ ! -d "$zsh_dir" ]; then
	git clone https://github.com/ohmyzsh/ohmyzsh.git "$zsh_dir"
fi

clone_plugin() {
	repository=$1
	name=$2
	destination="$custom_dir/plugins/$name"

	if [ ! -d "$destination" ]; then
		mkdir -p "$(dirname "$destination")"
		git clone "$repository" "$destination"
	fi
}

clone_plugin https://github.com/zsh-users/zsh-autosuggestions zsh-autosuggestions
clone_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git zsh-syntax-highlighting
clone_plugin https://github.com/jeffreytse/zsh-vi-mode zsh-vi-mode

printf 'Oh My Zsh and plugins are ready.\n'
