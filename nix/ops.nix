# Cloud and cluster tooling. Laptop-only for now: argocd is not in the binary
# cache for this nixpkgs pin, so it compiles from source and dominates the first
# switch on a fresh host.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    argocd
    pulumi-bin
  ];
}
