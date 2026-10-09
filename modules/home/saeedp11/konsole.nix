# Konsole, for right-to-left text (Persian in Claude Code).
#
# Alacritty has no bidirectional text support, and a pty wrapper such as
# bicon cannot add it after the fact because Claude Code redraws in
# cursor-addressed pieces; Konsole reorders and shapes each line as it draws
# the screen. Mod+Shift+Return in ./niri/config.kdl opens it on the zellij
# session with the profile below.
#
# The profile turns off two Konsole defaults that make mixed Persian/English
# lines unreadable:
#
#   * BidiLineLTR forces every line to be left-to-right, so the Persian runs
#     are reversed in place but the sentence still flows left to right and
#     English words land in the wrong spot. Off, each line takes the
#     direction of its first strong character.
#   * BidiTableDirOverride counts box-drawing characters as strong LTR, and
#     every line inside a zellij pane starts with the frame's `│`, which
#     would make every line LTR again.
#
# Only the profile is managed: konsolerc and the window state are Konsole's
# own to rewrite.
{ pkgs, ... }:

{
  home.packages = [ pkgs.kdePackages.konsole ];

  xdg.dataFile."konsole/RTL.profile".text = ''
    [General]
    Name=RTL
    Parent=FALLBACK/

    [Terminal Features]
    BidiRenderingEnabled=true
    BidiLineLTR=false
    BidiTableDirOverride=false
  '';
}
