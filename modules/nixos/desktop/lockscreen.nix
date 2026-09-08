# Screen locker (qylock, from the flake input of the same name).
#
# Split out of ./sddm.nix: a lock screen and a display manager are separate
# concerns that only happened to share a themes directory.
{ ... }:

{
  programs.qylock = {
    enable = true;
    theme = "nier-automata";        # any directory name under themes/
    sddm.enable = false;             # installs theme + sets it active (default)
    quickshell.enable = true;       # adds `qylock-lock` to PATH (default)

    # Optional per-theme tweaks (replaces the interactive prompts):
    themeOptions = {
      terraria.backgroundMode = "time";              # time | random | static
      Genshin.backgroundMode = "time";
      clockwork.orbital = { themeMode = "dark"; enableWindup = true; };
      osu.gameMode = "menu";                         # menu | game
    };
  };
}
