# Zsh managed by Home Manager (replaces oh-my-zsh + zsh/zshrc).
#
# oh-my-zsh was mostly a plugin loader plus defaults from its lib/ folder.
# Each section below notes which oh-my-zsh piece it replaces, so behaviour
# stays familiar without loading oh-my-zsh itself.
#   Dropped on purpose: robbyrussell theme (starship draws the prompt),
#   the git plugin's aliases (gst, gco, ...), oh-my-zsh auto-update.
{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    # replaces oh-my-zsh running compinit (lib/completion.zsh)
    enableCompletion = true;
    # replace the zsh-autosuggestions / zsh-syntax-highlighting plugins
    # that install-omz.sh cloned into oh-my-zsh's custom/plugins
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # replaces oh-my-zsh lib/history.zsh (size, shared history, dedupe, timestamps)
    history = {
      size = 50000;
      save = 50000;
      share = true;
      ignoreDups = true;
      ignoreSpace = true;
      extended = true;
    };

    # zsh-vi-mode: was the third custom plugin in install-omz.sh
    plugins = [
      {
        name = "zsh-vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
    ];

    # your own aliases from zsh/zshrc (not from oh-my-zsh)
    shellAliases = {
      r = "ranger";
      dockernuke = "docker ps -aq | xargs -r docker rm -f; docker system prune -af --volumes";
      pt = "polytoken";
      ptn = "polytoken new";
      ptc = "polytoken continue";
    };

    initContent = ''
      # --- oh-my-zsh replacements ---------------------------------------

      # from oh-my-zsh lib/misc.zsh: allow "# comments" in typed/pasted commands
      setopt interactive_comments

      # from oh-my-zsh lib/history.zsh: !! expands for review before running
      setopt hist_verify

      # from oh-my-zsh lib/completion.zsh: complete in the middle of a word,
      # move cursor to end after completing
      setopt complete_in_word always_to_end

      # from oh-my-zsh lib/directories.zsh: type a dir name to cd into it,
      # keep a stack of visited dirs (used by `d` and 1-9 below)
      setopt auto_cd auto_pushd pushd_ignore_dups pushd_minus

      # from oh-my-zsh lib/completion.zsh: arrow-key menu, case-insensitive and
      # partial-word matching, show . and .., color entries like ls
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' special-dirs true
      if command -v dircolors >/dev/null; then eval "$(dircolors -b)"; fi
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

      # from oh-my-zsh lib/theme-and-appearance.zsh (colored ls)
      # and lib/directories.zsh (l, la, ll, lsa)
      if [[ "$OSTYPE" == darwin* ]]; then alias ls='ls -G'; else alias ls='ls --color=auto'; fi
      alias l='ls -lah' la='ls -lAh' ll='ls -lh' lsa='ls -lah'

      # from oh-my-zsh lib/directories.zsh: .. / ... / ...., `-` = previous dir,
      # `d` lists recent dirs, 1-9 jump back to them
      alias ..='cd ..' ...='cd ../..' ....='cd ../../..'
      alias -- -='cd -'
      alias d='dirs -v | head -n 10'
      for i in {1..9}; do alias "$i"="cd -$i"; done; unset i
      # from oh-my-zsh lib/functions.zsh: take = mkdir + cd
      # (simplified: the oh-my-zsh version also handles URLs/tarballs)
      take() { mkdir -p -- "$1" && cd -- "$1"; }

      # from oh-my-zsh lib/termsupport.zsh: window/tab title shows the current
      # dir, plus the running command while it runs
      autoload -Uz add-zsh-hook
      _title_precmd()  { print -Pn "\e]0;%~\a"; }
      _title_preexec() { print -Pn "\e]0;%~: "; print -rn -- "$1"; print -n "\a"; }
      add-zsh-hook precmd _title_precmd
      add-zsh-hook preexec _title_preexec
      # ------------------------------------------------------------------

      # from oh-my-zsh lib/key-bindings.zsh: Ctrl+P/N and Up/Down search history
      # by what you've typed so far. Set after zsh-vi-mode, which resets bindings,
      # along with fzf's Ctrl+R / Ctrl+T.
      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      function zvm_after_init() {
        source <(fzf --zsh)
        bindkey -M viins '^P' up-line-or-beginning-search
        bindkey -M viins '^N' down-line-or-beginning-search
        bindkey -M viins '^[[A' up-line-or-beginning-search
        bindkey -M viins '^[[B' down-line-or-beginning-search
        bindkey -M vicmd 'k' up-line-or-beginning-search
        bindkey -M vicmd 'j' down-line-or-beginning-search
      }

      # Node versions via fnm (replaces nvm): auto-switches on cd when a
      # directory has .nvmrc / .node-version.  fnm install 22 / fnm use 22 / fnm default 22
      eval "$(fnm env --use-on-cd --shell zsh)"

      # worktrunk: lets `wt switch` change your shell's directory, plus completions
      eval "$(wt config shell init zsh)"

      # machine-specific / secret overrides, kept out of git (see .gitignore)
      [[ -r "$DOTFILES/zsh/paths.zsh.private" ]] && source "$DOTFILES/zsh/paths.zsh.private"
      [[ -r "$DOTFILES/private/secrets.zsh" ]] && source "$DOTFILES/private/secrets.zsh"
    '';
  };

  # Shell integrations (prompt config still comes from starship/starship.toml via install.sh)
  programs.starship.enable = true;
  programs.zoxide.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = false; # loaded in zvm_after_init above (after zsh-vi-mode)
  };
}
