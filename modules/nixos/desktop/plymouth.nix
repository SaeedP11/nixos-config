# Graphical boot splash, from the initrd handover to the greeter.
#
# ../core/boot.nix sets `boot.loader.timeout = 0`, so the firmware hands
# straight to the kernel with no menu; everything from that point to the
# login screen was raw text -- kernel ring buffer, then systemd's status
# lines -- against a black console, at whatever resolution the EFI
# framebuffer happened to be in. This module covers that window with one
# still image instead, and the kernel parameters below exist only to keep
# text from punching through it.
#
# All of it is here rather than in ../core/boot.nix so that the whole
# feature, splash and silence together, is one import to remove: `quiet`
# and a console log level of 0 are not things this machine wants on their
# own, they are the cost of the splash being visible.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # nixpkgs defaults this theme to the macchiato flavour. Mocha is the one the
  # rest of the desktop is on -- ./niri.nix seeds vicinae with catppuccin-mocha
  # -- and it is the darkest of the four, so the splash matches the greeter
  # that follows it rather than being a lighter rectangle in front of it.
  #
  # The theme draws on #1e1e2e (mocha base) with a 204x34 throbber strip below
  # the header image, and is `two-step`, a module plymouth ships, so nothing is
  # compiled and the whole package is 68K.
  theme = pkgs.catppuccin-plymouth.override { variant = "mocha"; };

  # The client binary for the ExecStart override at the bottom, built the way
  # the plymouth module builds it rather than as a plain `pkgs.plymouth`: the
  # module overrides plymouth's systemd input so plymouthd links against the
  # initrd's systemd. On 25.05 the two are the same derivation and this is a
  # no-op, which is exactly why it is written out -- if they ever diverge, a
  # plain reference would quietly add a second plymouth to the closure instead
  # of pointing at the one already there.
  plymouth = pkgs.plymouth.override { systemd = config.boot.initrd.systemd.package; };
in
{
  boot.plymouth = {
    enable = true;
    themePackages = [ theme ];
    theme = "catppuccin-mocha";

    # `two-step` centres this above the throbber, and the plymouth module
    # symlinks whatever is set here in as the theme's header-image.png. The
    # default is the 48x48 icon, sized to sit beside GDM's text; against a
    # 204px throbber on a 1080p panel it reads as a speck, so take the 128px
    # rendering of the same white snowflake.
    logo = "${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake-white.png";

    # The theme asks for "Noto Sans" by name, and the initrd carries exactly
    # one font file with a fontconfig pointing at it -- whatever is named here.
    # Left at the default, every string the theme draws would resolve to
    # DejaVu; ../desktop/fonts.nix already installs noto-fonts system-wide, so
    # this only costs the one file in the initrd.
    font = "${pkgs.noto-fonts}/share/fonts/noto/NotoSans[wdth,wght].ttf";
  };

  # Everything below is about keeping the splash the only thing on screen.
  #
  # `boot.initrd.verbose` is deliberately not set: it is read by the generated
  # stage-1 *shell script*, which ../core/boot.nix replaced with systemd, so it
  # would be a no-op here. The rd.* parameters are its equivalent.
  boot.consoleLogLevel = 0;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=false"
    # The console's blinking cursor is drawn by the VT layer, not by plymouth,
    # and sits on top of the splash in the corner it was left in.
    "vt.global_cursor_default=0"
  ];

  # Without this the splash is torn down before the greeter exists, so the
  # sequence is splash, black console for as long as the greeter takes to start, then
  # greeter. --retain-splash leaves the last frame on the framebuffer when
  # plymouthd exits, so that gap holds the image instead, and the greeter draws
  # over it -- nothing else changes, display-manager.service (greetd) is
  # already ordered after plymouth-quit-wait.service by the greetd module.
  #
  # The cost is that a display manager which fails to start now fails behind a
  # frozen splash rather than in front of a console. The VT is still live:
  # Ctrl+Alt+F2 repaints and gives a login.
  #
  # The empty first entry clears the package's own ExecStart, which systemd
  # would otherwise see twice. The `-` prefix is carried over from that line
  # and is not decoration: `plymouth quit` exits 1 when no plymouthd is
  # listening, which is every `nixos-rebuild switch` on a system that booted
  # before this module existed, or after `systemctl start` on a running
  # desktop. Without it the switch ends in "the following units failed".
  systemd.services.plymouth-quit.serviceConfig.ExecStart = lib.mkForce [
    ""
    "-${lib.getExe' plymouth "plymouth"} quit --retain-splash"
  ];
}
