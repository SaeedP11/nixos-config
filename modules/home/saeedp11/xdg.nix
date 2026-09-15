# Which application opens what.
#
# ~/.config/mimeapps.list was hand-edited and is the reason a Telegram link,
# a PNG or a `claude-cli://` URL opens the program it does rather than
# whatever the desktop files happen to rank first. It is small, purely
# declarative, and exactly the kind of thing that silently disappears on a
# reinstall, so it belongs here.
#
# WHY SO MANY ORDINARY TYPES ARE PINNED BELOW. A type with no entry here is
# not unhandled -- xdg-open falls back to whichever .desktop file sorts first
# in mimeinfo.cache for it, which is arbitrary and changes as packages come
# and go. That fallback had picked genuinely wrong answers: inode/directory
# resolved to org.gnome.baobab.desktop, so "Open Containing Folder" from
# Firefox and `xdg-open .` both opened the Disk Usage Analyzer rather than the
# file manager, and text/plain resolved to gvim.desktop, whose TryExec=gvim
# names a binary nothing in this configuration installs, so opening a text
# file did nothing at all. Declaring the common families keeps those answers
# stable across rebuilds instead of leaving them to cache ordering.
#
# THE TRADE-OFF. xdg.mimeApps makes the file a read-only store symlink, so
# "Set as default" in a file manager's Open With dialog, and `xdg-mime
# default` on the command line, both stop taking effect -- they write to
# this file. Add the association here and rebuild instead.
{ ... }:

{
  # Preference order for `Terminal=true` desktop entries, read by the
  # xdg-terminal-exec that ../../nixos/desktop/niri.nix installs. One desktop
  # entry id per line, most preferred first. Without this file it would fall
  # back to guessing, and without the command GLib does the guessing itself
  # from a list that has no alacritty in it.
  xdg.configFile."xdg-terminals.list".text = ''
    Alacritty.desktop
  '';

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      # Claude Code installs this handler into ~/.local/share/applications;
      # it is what makes a claude-cli:// link resume a session.
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";

      # Folders. See the note above: this was baobab.
      "inode/directory" = "thunar.desktop";

      # Web
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";

      # Documents
      "application/pdf" = "org.gnome.Papers.desktop";

      # Text and code. VS Code rather than vim.desktop or nvim.desktop:
      # those are console entries, and while xdg-terminal-exec now makes them
      # launchable, a double-click in a file manager wants a window.
      "text/plain" = "code.desktop";
      "text/markdown" = "code.desktop";
      "application/json" = "code.desktop";
      "application/xml" = "code.desktop";
      "text/x-shellscript" = "code.desktop";

      # Images
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";

      # Audio and video
      "audio/mpeg" = "mpv.desktop";
      "audio/flac" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
      "audio/x-wav" = "mpv.desktop";
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";

      # Archives. file-roller is also what thunar-archive-plugin drives from
      # the Extract Here / Create Archive context menu that
      # ../../nixos/programs/gui.nix now actually loads.
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
      "application/vnd.rar" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/gzip" = "org.gnome.FileRoller.desktop";
      "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-xz-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/zstd" = "org.gnome.FileRoller.desktop";
    };

    associations.added = {
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      # Code is the default above; vim is here so it stays in the Open With
      # list for the times a console editor is what is wanted.
      "application/json" = [
        "code.desktop"
        "vim.desktop"
      ];
      "text/plain" = [
        "code.desktop"
        "vim.desktop"
      ];
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
