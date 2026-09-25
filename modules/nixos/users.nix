# User account(s).
#
# Per-user packages and dotfiles are Home Manager's job now -- see
# ../home/. What stays here is only what the *system* needs to know: the
# account, its groups, its login shell and the password it is created with.
{ pkgs, vars, ... }:

{
  users.users.${vars.username} = {
    isNormalUser = true;
    description = "Saeed P11";
    extraGroups = [
      "wheel"
      "docker"
      "input"
      "video"
      "audio"
      "network"
      "netdev"
      "tty"
      "disk"
      "plugdev"
      "pipewire"
      "bluetooth"
      "networkmanager"
      "storage"
      "seat"
    ];
    shell = pkgs.fish;

    # WHY THIS EXISTS AT ALL. `users.mutableUsers` is left at its default of
    # true, so the real password lives in /etc/shadow and is changed with
    # `passwd` -- which is fine on a machine that has one, and useless on a
    # machine that does not. Without a password declared anywhere, a fresh
    # install from this flake creates the account with no password set: the
    # greeter cannot log it in (PAM will not accept an empty one) and `sudo` fails,
    # so the only way in is a root shell from the installer. Every other
    # thing this repository configures is unreachable until that is fixed by
    # hand, which is precisely the kind of manual step the repository exists
    # to remove.
    #
    # `initialHashedPassword`, not `hashedPassword`: it is consulted only
    # when the account is *created*. On these two machines the account
    # already exists, so this line changes nothing and cannot overwrite the
    # password either of them is actually using. It is the bootstrap value
    # for the next machine and nothing else.
    #
    # The hash below is SHA-512 of the literal string "changeme". It is a
    # throwaway that must be replaced with `passwd` at the first login, and
    # it is written out in the clear on the assumption that anyone reading
    # this repository can read this comment too -- a salted hash of a known
    # word protects nothing. Do not put a real password's hash here: even
    # SHA-512 is cheap to attack offline. To bootstrap with a real secret
    # instead, drop this line for
    #
    #     hashedPasswordFile = "/persist/passwd/${vars.username}";
    #
    # and place that file by hand before the first boot, or bring in
    # sops-nix/agenix.
    initialHashedPassword = "$6$oS0sU89fKMFC0Pum$EgAUACT2d7JpHw49h5NyMRXrc7ftfapc3vPW/01dvbTP/2RnvaoBS5ieQF3NNPE3MxoT2Ab0C4PPdJWRrC801.";
  };

  # Same reasoning for root, which is otherwise left with no password at all
  # and so cannot be used for recovery from a console. wheel + sudo is the
  # normal path in; this is the way back when that account is the broken one.
  users.users.root.initialHashedPassword = "$6$oS0sU89fKMFC0Pum$EgAUACT2d7JpHw49h5NyMRXrc7ftfapc3vPW/01dvbTP/2RnvaoBS5ieQF3NNPE3MxoT2Ab0C4PPdJWRrC801.";
}
