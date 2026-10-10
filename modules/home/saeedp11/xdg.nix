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
      # DjVu went to Okular by cache order; Papers reads it too and is the
      # viewer for every other paged document here.
      "image/vnd.djvu" = "org.gnome.Papers.desktop";
      "image/vnd.djvu+multipage" = "org.gnome.Papers.desktop";
      # Plain-text office formats: LibreOffice first, Fresh second. The first
      # entry that is installed wins, so on a host with LibreOffice switched
      # off in ../../nixos/apps.nix these open in Fresh instead of nothing.
      # The binary formats (.docx, .xlsx, .odt...) get no Fresh fallback --
      # a text editor is no use for them.
      "text/csv" = [
        "calc.desktop"
        "fresh.desktop"
      ];
      "text/tab-separated-values" = [
        "calc.desktop"
        "fresh.desktop"
      ];
      "application/rtf" = [
        "writer.desktop"
        "fresh.desktop"
      ];

      # Fonts. Font Manager and gnome-font-viewer both claim these, and .otf
      # also matches LibreOffice Math's formula-template glob, so the
      # previewer is pinned rather than left to cache order.
      "font/ttf" = "org.gnome.font-viewer.desktop";
      "font/otf" = "org.gnome.font-viewer.desktop";
      "font/woff" = "org.gnome.font-viewer.desktop";

      # Text and code. Fresh (../../../pkgs/fresh-editor.nix, installed by
      # ../../nixos/programs/cli.nix) rather than VS Code, which a host can
      # now switch off in ../../nixos/apps.nix. fresh.desktop is a
      # Terminal=true entry, so a double-click opens it in Alacritty through
      # the xdg-terminal-exec preference list above.
      "text/plain" = "fresh.desktop";
      "text/markdown" = "fresh.desktop";
      "application/json" = "fresh.desktop";
      "application/xml" = "fresh.desktop";
      "text/x-shellscript" = "fresh.desktop";
      # What shared-mime-info actually calls a .sh file; text/x-shellscript
      # above is only its alias. Left unpinned, it and C sources went to
      # nvim.desktop, a console entry picked by cache order.
      "application/x-shellscript" = "fresh.desktop";
      "text/x-csrc" = "fresh.desktop";

      # Images
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";

      # Audio and video
      "audio/mpeg" = "vlc.desktop";
      "audio/flac" = "vlc.desktop";
      "audio/ogg" = "vlc.desktop";
      "audio/x-wav" = "vlc.desktop";
      "video/mp4" = "vlc.desktop";
      "video/x-matroska" = "vlc.desktop";
      "video/webm" = "vlc.desktop";
      "video/quicktime" = "vlc.desktop";
      "video/x-msvideo" = "vlc.desktop";

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
      # .xz went to Impression, which claims it for compressed disk images;
      # a disk image is the rarer .xz, and Impression is still in Open With.
      "application/x-xz" = "org.gnome.FileRoller.desktop";
      "application/x-bzip2" = "org.gnome.FileRoller.desktop";
      "application/x-bzip2-compressed-tar" = "org.gnome.FileRoller.desktop";
    };

    associations.added = {
      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
      # Fresh is the default above; Code and vim are here so they stay in the
      # Open With list -- Code for when a window is wanted, on hosts that
      # still install it.
      "application/json" = [
        "fresh.desktop"
        "code.desktop"
        "vim.desktop"
      ];
      "text/plain" = [
        "fresh.desktop"
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
      # Papers is the default above and stays the one a double-click opens.
      # Okular is here for the PDFs Papers can read but not complete: it is
      # what verifies and applies digital signatures, and its form and
      # annotation tools are the ones that hold up on an official form.
      "application/pdf" = [
        "org.gnome.Papers.desktop"
        "org.kde.okular.desktop"
      ];
    };
  };
}
