# Development toolchains and dependencies.
#
# These are system-wide rather than per-project on purpose. If any of them
# start to conflict, the Nix-native answer is a per-project `nix develop`
# shell rather than more entries here.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages =
    with pkgs;
    [
      rustup
      gcc
      pkg-config
      openssl

      nodejs_26
      pnpm

      # For pip-only CLI tools that have no nixpkgs derivation.
      pipx

      mysql-client
    ]
    # Switched per host in ../apps.nix.
    ++ lib.optional config.apps.insomnia.enable pkgs.insomnia;
}
