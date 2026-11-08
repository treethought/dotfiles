if [[ "$(uname -s)" == "Darwin" ]]; then
	if [[ -d "/Applications/Ghostty.app/Contents/MacOS" ]]; then
		export PATH="$PATH:/Applications/Ghostty.app/Contents/MacOS"
	fi
	if [[ -d "/opt/homebrew/opt/libpq/bin" ]]; then
		export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
	fi
fi
