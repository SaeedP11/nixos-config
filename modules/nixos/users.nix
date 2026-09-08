# User account(s).
#
# Per-user packages and dotfiles are Home Manager's job now -- see
# ../home/. What stays here is only what the *system* needs to know: the
# account, its groups, and its login shell.
{ pkgs, vars, ... }:

{
  users.users.${vars.username} = {
    isNormalUser = true;
    description = "Saeed P11";
    extraGroups = [
      "wheel" "docker" "input" "video" "audio" "network" "netdev"
      "tty" "disk" "plugdev" "pipewire" "bluetooth" "networkmanager"
      "storage" "seat"
    ];
    shell = pkgs.fish;
  };
}
