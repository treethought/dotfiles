{
  description = "treethought dotfiles: Home Manager for Linux (Fedora) and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      mkHome = system: modules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
          modules = [ ./nix/common.nix ] ++ modules;
        };
    in {
      homeConfigurations = {
        # Fedora Framework laptop:  home-manager switch --flake ~/dotfiles#framework
        "framework" = mkHome "x86_64-linux" [ ./nix/linux.nix ];
        # Work Mac:                 home-manager switch --flake ~/dotfiles#mac
        "mac" = mkHome "aarch64-darwin" [ ./nix/darwin.nix ];
      };
    };
}
