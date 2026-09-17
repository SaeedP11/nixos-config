# Graphical applications. Session components that are part of the niri
# desktop itself (bar, launcher, terminal, screenshot tools) live in
# ../desktop/niri.nix instead.
{ pkgs, ... }:

{
  # Thunar comes from its NixOS module rather than environment.systemPackages,
  # for two things only the module does.
  #
  # It builds the file manager as `xfce.thunar.override { thunarPlugins = ... }`.
  # That matters because libthunarx-3 has its own store path's lib/thunarx-3
  # compiled in as the plugin directory and consults no other unless
  # THUNARX_DIRS is set, while a plugin installed as a package of its own lands
  # in /run/current-system/sw/lib/thunarx-3 -- somewhere Thunar never looks. So
  # thunar-archive-plugin used to be installed, present on disk, and never
  # loaded: file-roller was here the whole time but Extract Here and Create
  # Archive never appeared in the context menu.
  #
  # It also turns on programs.xfconf, and xfconfd is where Thunar keeps nearly
  # every preference -- view mode, sidebar, hidden files, single vs double
  # click, the volume management toggle thunar-volman hangs off. Nothing else
  # in this configuration pulls it in, so there was no such service on the
  # session bus, ~/.config/xfce4/xfconf/ was never created, and every setting
  # made in the preferences dialog was gone by the next launch.
  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  environment.systemPackages = with pkgs; [
    # File management. Thunar itself is the programs.thunar block above.
    xfce.tumbler
    file-roller
    baobab

    # Bootable USB media. ventoy-full-gtk, not ventoy or ventoy-full: the
    # filesystem backends (cryptsetup, xfs, ext4, ntfs) are what -full adds,
    # while the GUI is a separate override -- without a defaultGuiType the
    # package installs no `ventoy-gui` and no desktop entry at all, only the
    # Ventoy2Disk shell wrappers. gtk3 over qt5 because the rest of this
    # desktop is GTK. Writing a stick needs root either way, so the launcher
    # entry only works from a root session; `sudo ventoy` is the shell path.
    #
    # Ventoy prepares the stick once and then boots any ISO copied onto its
    # exFAT partition, which is the everyday case; impression is for the times
    # an image has to be written raw over the whole device, the job
    # balenaEtcher did before it was dropped from nixpkgs.
    ventoy-full-gtk
    impression

    # Media
    vlc
    mpv
    # Screen recorder. Captures through the xdg-desktop-portal ScreenCast
    # interface (../desktop/portals.nix routes it to wlr) and PipeWire, so it
    # works under niri; GNOME's own recorder is a gnome-shell built-in and
    # ships no standalone package.
    kooha

    # Documents. Nothing here opened a PDF before -- application/pdf resolved
    # to nothing at all, so a PDF saved out of Firefox and clicked in Thunar
    # did nothing. Papers is the GNOME 48 successor to Evince and fits the
    # rest of the GNOME accessories below.
    papers
    # Okular for the PDFs Papers only half-handles: digitally signed ones,
    # which it verifies and can sign, and interactive forms, where its widget
    # support is the one that holds up. Papers stays the default handler in
    # ../../home/saeedp11/xdg.nix; this is the second entry in Open With.
    # It is the one Qt/KDE application on an otherwise GTK desktop, so it
    # brings a KDE Frameworks closure of its own and its dialogs will not
    # match -- the signature and form support is what pays for that.
    kdePackages.okular

    # Office suite. The plain `libreoffice` attribute is the wrapped Fresh
    # build -- the wrapper is what puts the GTK VCL plugin and the bundled JRE
    # on the path, so the dialogs match the rest of this desktop instead of
    # falling back to the X11 plugin, and Base and the wizards have a Java
    # runtime to find. It is .odt/.ods/.odp natively, reads and writes
    # .docx/.xlsx/.pptx, and is the only thing here that opens the legacy
    # .doc/.xls/.ppt, .rtf, .wpd and .pub or converts from a script with
    # `soffice --headless --convert-to`.
    #
    # It stands alone where onlyoffice-desktopeditors used to sit beside it.
    # ONLYOFFICE was here for closer OOXML round-tripping, which is not worth
    # keeping a second suite installed for -- and it was the heavier of the
    # two, a prebuilt unfree Electron bundle.
    libreoffice

    # Settings / system UI
    pavucontrol
    networkmanagerapplet
    gnome-control-center
    gnome-system-monitor

    # GNOME accessories
    gnome-calendar
    gnome-clocks
    gnome-characters
    gnome-calculator
    # gnome-font-viewer previews one file at a time and is what supplies the
    # font thumbnailer; font-manager is the browser over everything installed
    # -- specimens by family, face comparison, licence and metadata, and the
    # enable/disable toggles. Those toggles and its install button write to
    # ~/.local/share/fonts, which is a real directory again now that the
    # ONLYOFFICE workaround that owned it is gone. Anything wanted on this
    # machine for good still belongs in ../desktop/fonts.nix; what is added
    # through the GUI is user-local and will not survive a migration.
    font-manager
    gnome-font-viewer
    snapshot
  ];
}
