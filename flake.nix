{
  description = "treethought dotfiles: shared and platform-specific Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # NUR: community package repos (e.g. Charm's, for crush)
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative Flatpak apps (Linux only), see nix/flatpak.nix
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
  };

  outputs = { nixpkgs, home-manager, nur, nix-flatpak, ... }:
    let
      mkHome = system: modules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ nur.overlays.default ]; # adds pkgs.nur.repos.*
          };
          modules = [ ./nix/common.nix ] ++ modules;
        };
    in {
      homeConfigurations = {
        # Fedora Framework laptop:  home-manager switch --flake ~/dotfiles#framework
        "framework" = mkHome "x86_64-linux" [
          nix-flatpak.homeManagerModules.nix-flatpak
          ./nix/linux.nix
        ];
        # Work Mac:                 home-manager switch --flake ~/dotfiles#mac
        "mac" = mkHome "aarch64-darwin" [ ./nix/darwin.nix ];
      };
    };
}
