# The interactive shell's user-side configuration: fish's own startup file
# and starship's prompt definition.
#
# The *programs* are enabled system-wide in ../../nixos/programs/shell.nix,
# which also runs `starship init fish` through fish's promptInit. Neither is
# re-enabled here:
#
#   * programs.starship is deliberately NOT set. Home Manager's starship
#     module writes its own fish integration, and the prompt would then be
#     initialised twice in every interactive shell. Only the config file is
#     claimed, which is all that was ever hand-placed.
#   * programs.fish IS enabled, because that is the only way to get a managed
#     ~/.config/fish/config.fish. It does not compete with the system module:
#     fish reads /etc/fish/config.fish (where starship's init lands) before
#     the user's, so both still run, in that order.
#
# ~/.config/fish/fish_variables stays unmanaged -- fish rewrites it whenever
# a universal variable changes, which is most of what that file is for.
{ ... }:

{
  programs.fish = {
    enable = true;

    # Formerly the body of a hand-written ~/.config/fish/config.fish. The
    # two entries are pnpm's global bin directory and ~/.local/bin; both are
    # guarded so that a nested shell does not prepend them a second time.
    # Written out rather than expressed as home.sessionPath so the resulting
    # PATH does not depend on Home Manager's session-variable plumbing being
    # sourced, which is what the hand-written file did not depend on either.
    shellInit = ''
      set -gx PNPM_HOME "$HOME/.local/share/pnpm"
      if not contains -- $PNPM_HOME $PATH
          set -gx PATH $PNPM_HOME $PATH
      end

      if not contains -- "$HOME/.local/bin" $PATH
          set -gx PATH "$HOME/.local/bin" $PATH
      end
    '';
  };

  xdg.configFile."starship.toml".source = ./starship.toml;
}
