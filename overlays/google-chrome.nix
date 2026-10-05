# Google Chrome from nixos-unstable.
#
# Google only hosts the current .deb on dl.google.com and deletes old ones, so
# a google-chrome pinned by 25.05 -- end-of-life and no longer bumped -- stops
# building as soon as Google moves on (143.0.7499.169 is a 404). Unstable
# follows Chrome releases, so taking the attribute from there keeps the fetch
# working; `nix flake update nixpkgs-unstable` picks up a newer build if it
# 404s again.
#
# Unstable is imported rather than read through legacyPackages because the
# package is unfree, and legacyPackages carries no allowUnfree.
{ inputs }:

final: prev: {
  google-chrome =
    (import inputs.nixpkgs-unstable {
      system = prev.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    }).google-chrome;
}
