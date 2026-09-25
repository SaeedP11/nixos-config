# Screen locker: the Quickshell lock screen
# (../../home/saeedp11/quickshell/modules/lock), which replaced qylock.
#
# The lock itself needs no package here -- it is part of the shell -- only
# the PAM service it authenticates against, /etc/pam.d/quickshell-lock.
# A service of its own rather than borrowing `login`, which would also run
# login's session modules on every unlock. The defaults give it pam_unix,
# the same as swaylock's.
#
# Separate from the login screen (./greeter.nix): a lock screen and a
# display manager are separate concerns.
{ ... }:

{
  security.pam.services.quickshell-lock = { };
}
