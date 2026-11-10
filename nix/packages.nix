# Everything installed by Nix. Add a name, then: home-manager switch --flake ~/dotfiles#framework
# Find names with: nix search nixpkgs <name>
# fzf, starship and zoxide are installed via nix/zsh.nix (programs.*).
{pkgs, ...}: let
  ntnVersion = "0.23.28";
  ntn = pkgs.stdenvNoCC.mkDerivation {
    pname = "ntn";
    version = ntnVersion;
    src = pkgs.fetchurl {
      url = "https://ntn.dev/releases/v${ntnVersion}/ntn-${
        if pkgs.stdenv.isDarwin
        then
          if pkgs.stdenv.isAarch64
          then "aarch64-apple-darwin"
          else "x86_64-apple-darwin"
        else "x86_64-unknown-linux-musl"
      }.tar.gz";
      hash =
        if pkgs.stdenv.isDarwin
        then
          if pkgs.stdenv.isAarch64
          then "sha256-l1XK+f6qqiYrANqE2U0FcaHn3VVMjFMZLAw5454MZkM="
          else "sha256-Ed6euf0o4El9sNBenDWMQ8z8PZCVk65WV10yi7gPVHE="
        else "sha256-y73AMRe3hsMeHJJE+I1TWL7y+QkW/s2cLgYDre8C+2Q=";
    };
    sourceRoot = "ntn-${
      if pkgs.stdenv.isDarwin
      then
        if pkgs.stdenv.isAarch64
        then "aarch64-apple-darwin"
        else "x86_64-apple-darwin"
      else "x86_64-unknown-linux-musl"
    }";
    installPhase = ''
      install -Dm755 ntn $out/bin/ntn
    '';
    meta.mainProgram = "ntn";
  };
in {
  home.packages = with pkgs; [
    # core CLI
    bat
    btop
    curl
    dust
    gh
    git
    git-lfs
    glow
    jq
    just
    lazygit
    lnav
    neovim
    pv
    ranger
    rclone
    ripgrep
    _7zz
    tmux
    websocat
    wget
    yt-dlp
    zellij
    ffmpeg
    librepods

    # languages / dev
    go
    pipx
    postgresql # psql (replaces brew libpq/postgresql@18)
    fnm # Node version manager (nvm replacement, reads .nvmrc), set up in zsh.nix
    bun
    ntn

    # harnesses / agents
    codex
    opencode
    nur.repos.charmbracelet.crush # Charm's recommended NUR Nix source
    tuicr # TUI code review
    herdr # terminal runtime for coding agents
    worktrunk # wt: git worktrees
    gcx

    # cloud / k8s
    argocd
    awscli2
    kubectl
    kubectx
    k9s
    pulumi-bin

    # fonts
    inter
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.hack
    nerd-fonts.caskaydia-cove
    nerd-fonts.caskaydia-mono
    nerd-fonts.commit-mono
    nerd-fonts.meslo-lg
    nerd-fonts.ubuntu-mono
    nerd-fonts.inconsolata-go
    nerd-fonts._0xproto
    nerd-fonts.monofur
    nerd-fonts.overpass
  ];
}
