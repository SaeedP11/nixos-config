# System-wide `programs.*` enables that don't belong to the shell, the
# desktop, or the dev toolchain.
{ ... }:

{
  # The git *package* system-wide, so root has it too (`sudo nixos-rebuild
  # --flake` needs it). The per-user identity lives in Home Manager
  # (../../home/saeedp11/git.nix), which writes ~/.config/git/config and
  # therefore overrides /etc/gitconfig.
  programs.git.enable = true;

  programs.firefox.enable = true;

  programs.nekoray = {
    enable = true;
    tunMode.enable = true;
  };

  # Lets unpatched dynamically-linked binaries (rustup toolchains, npm
  # prebuilts, pipx wheels) find a loader.
  programs.nix-ld.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
