#!/bin/sh
# Fuzzy session picker for zellij (bound to prefix + s).
# Pick an existing session to switch to it, or type a name that matches
# nothing and press enter to create a new session with that name.
# ctrl-k kills the highlighted session (keeps it resurrectable),
# ctrl-d deletes it entirely. The current session is never killed/deleted.

fzf=$(command -v fzf)
zellij=$(command -v zellij)

if [ -z "$fzf" ] || [ -z "$zellij" ]; then
	printf '%s\n' 'session picker requires fzf and zellij' >&2
	exit 1
fi

list="$zellij list-sessions --no-formatting | sed 's/ (current)$//'"
guard='[ "$1" != "$ZELLIJ_SESSION_NAME" ] &&'

choice=$(sh -c "$list" | "$fzf" \
	--prompt='session> ' \
	--header='enter: switch | ctrl-k: kill | ctrl-d: delete | no match + enter: create' \
	--layout=reverse --height=100% --border=none \
	--bind='enter:accept-or-print-query' \
	--bind="ctrl-k:execute-silent(sh -c '$guard $zellij kill-session \"\$1\"' _ {2})+reload($list)" \
	--bind="ctrl-d:execute-silent(sh -c '$guard $zellij delete-session --force \"\$1\"' _ {2})+reload($list)")

[ -z "$choice" ] && exit 0

if [ "$choice" = "$ZELLIJ_SESSION_NAME" ]; then
	exit 0
fi

exec "$zellij" action switch-session "$choice"
