# Everything installed by Nix. Add a name, then: home-manager switch --flake ~/dotfiles#framework
# Find names with: nix search nixpkgs <name>
# fzf, starship and zoxide are installed via nix/zsh.nix (programs.*).
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # core CLI
    bat btop curl dust gh git git-lfs glow jq just lazygit lnav
    neovim pv ranger rclone ripgrep _7zz tmux
    websocat wget yt-dlp zellij ffmpeg
    librepods

    # languages / dev
    go
    pipx
    postgresql   # psql (replaces brew libpq/postgresql@18)
    fnm          # Node version manager (nvm replacement, reads .nvmrc), set up in zsh.nix
    bun


    # harnesses / agents
    nur.repos.charmbracelet.crush   # Charm's recommended NUR Nix source
    tuicr       # TUI code review
    herdr       # terminal runtime for coding agents
    worktrunk   # wt: git worktrees
    gcx

    # cloud / k8s
    argocd awscli2 kubectx k9s pulumi-bin

    # fonts
    inter
    nerd-fonts.jetbrains-mono nerd-fonts.fira-code nerd-fonts.fira-mono
    nerd-fonts.hack nerd-fonts.caskaydia-cove nerd-fonts.caskaydia-mono
    nerd-fonts.commit-mono nerd-fonts.meslo-lg nerd-fonts.ubuntu-mono
    nerd-fonts.inconsolata-go nerd-fonts._0xproto nerd-fonts.monofur
    nerd-fonts.overpass

  ];
}
