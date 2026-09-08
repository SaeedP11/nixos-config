# Git identity.
#
# The git *package* stays system-wide (modules/nixos/programs/misc.nix) so
# root has it too -- `sudo nixos-rebuild --flake` needs it. Only the
# per-user identity, which never belonged in a system module, lives here.
# ~/.config/git/config overrides /etc/gitconfig, so this wins.
{ ... }:

{
  programs.git = {
    enable = true;
    userName = "saeedp11";
    userEmail = "saeed_abdi.p11@outlook.com";
    extraConfig = {
      core.editor = "vim";
      pull.rebase = false;
    };
  };
}
