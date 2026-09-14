# Which application opens what.
#
# ~/.config/mimeapps.list was hand-edited and is the reason a Telegram link,
# a PNG or a `claude-cli://` URL opens the program it does rather than
# whatever the desktop files happen to rank first. It is small, purely
# declarative, and exactly the kind of thing that silently disappears on a
# reinstall, so it belongs here.
#
# THE TRADE-OFF. xdg.mimeApps makes the file a read-only store symlink, so
# "Set as default" in a file manager's Open With dialog, and `xdg-mime
# default` on the command line, both stop taking effect -- they write to
# this file. Add the association here and rebuild instead.
{ ... }:

{
  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      "image/png" = "org.gnome.Loupe.desktop";
      # Claude Code installs this handler into ~/.local/share/applications;
      # it is what makes a claude-cli:// link resume a session.
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
    };

    associations.added = {
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      "application/json" = "vim.desktop";
      # Loupe is the default above; satty is here so it shows up in a PNG's
      # Open With list, which is where the annotation editor is wanted -- the
      # live file had grown this entry by hand after ../../nixos/desktop/niri.nix
      # installed satty, and it is written down here so the next rebuild stops
      # clobbering it.
      "image/png" = [
        "org.gnome.Loupe.desktop"
        "satty.desktop"
      ];
    };
  };
}
