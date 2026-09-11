# XboxDownload (Xbox下载助手): points the download CDNs of Xbox, the Microsoft
# Store, PlayStation, Switch, EA, Battle.net, Epic, Ubisoft, Riot and Rockstar
# at whichever of their edge IPs is actually fast from here, by answering DNS
# for their hostnames itself and proxying the HTTP that follows.
#
# Upstream is a .NET 10 Avalonia app published as a self-contained single-file
# binary; nixpkgs 25.05 carries no .NET 10 SDK, so there is nothing to build
# from source here and this repackages the official linux-x64 release. The
# bundled run_xboxdownload.sh is dropped: all it does is find the binary,
# re-exec itself under sudo and nohup the result, which `sudo xboxdownload`
# covers without the guesswork.
#
# One upstream feature cannot work here whatever this derivation does: the
# "apply to hosts file" buttons write /etc/hosts directly, and on NixOS that is
# a symlink into the store and so read-only even for root. The DNS server the
# app runs is the path that matters for the consoles anyway; for this machine,
# networking.extraHosts in a module is the declarative equivalent.
#
# The upstream project ships no licence of any kind, so this is marked unfree.
# ../modules/nixos/core/nix.nix sets allowUnfree, so the system build is fine;
# `nix build .#xboxdownload` needs NIXPKGS_ALLOW_UNFREE=1 --impure, since
# ../flake.nix builds its `packages` output from unconfigured nixpkgs.
{
  lib,
  stdenv,
  fetchzip,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  bash,
  coreutils,
  dbus,
  fontconfig,
  icu,
  krb5,
  libGL,
  openssl,
  systemd,
  util-linux,
  vulkan-loader,
  xorg,
}:

let
  version = "3.0.0.65";

  # dlopen()ed rather than linked, so autoPatchelfHook cannot see any of them:
  # .NET loads ICU by name, Avalonia's X11 backend P/Invokes libX11 and friends,
  # and the native halves of SkiaSharp and HarfBuzzSharp are unpacked out of the
  # single-file bundle at runtime and so carry no RPATH this derivation could
  # have written.
  runtimeLibs = [
    icu
    fontconfig
    libGL
    dbus
    openssl
    krb5
    vulkan-loader
    xorg.libX11
    xorg.libXcursor
    xorg.libXext
    xorg.libXi
    xorg.libXrandr
    xorg.libICE
    xorg.libSM
    stdenv.cc.cc.lib
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "xboxdownload";
  inherit version;

  src = fetchzip {
    url = "https://github.com/skydevil88/XboxDownload/releases/download/v${version}/XboxDownload-linux-x64.zip";
    hash = "sha256-Fp4iopOE8k0s40h1SAzbWJnh4GIhC6eAjLlik50/T8Y=";
  };

  # The release zip carries no icon, so take the one the sources build the
  # Windows .ico from, at the commit the release was cut from.
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/skydevil88/XboxDownload/v${version}/XboxDownload/Assets/xbox.png";
    hash = "sha256-bq3EgrAs1ZR/IkJ316cvfz8qL2WbL34Xo1PYX/XiVKk=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = runtimeLibs;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 XboxDownload $out/share/xboxdownload/XboxDownload
    install -Dm644 ${finalAttrs.icon} $out/share/icons/hicolor/256x256/apps/xboxdownload.png

    mkdir -p $out/bin
    substitute ${./xboxdownload-launch.sh} $out/bin/xboxdownload \
      --subst-var-by bash ${lib.getExe bash} \
      --subst-var out \
      --subst-var-by libraryPath ${lib.makeLibraryPath runtimeLibs} \
      --subst-var-by path ${
        lib.makeBinPath [
          bash
          coreutils
          systemd
          util-linux
          xorg.xhost
        ]
      }
    chmod +x $out/bin/xboxdownload

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "xboxdownload";
      desktopName = "XboxDownload";
      comment = "Redirect console and game store downloads to their fastest CDN edge";
      exec = "xboxdownload";
      icon = "xboxdownload";
      categories = [
        "Network"
        "Game"
      ];
      startupWMClass = "XboxDownload";
    })
  ];

  meta = {
    description = "Download accelerator for Xbox, PlayStation, Switch and PC game stores";
    homepage = "https://github.com/skydevil88/XboxDownload";
    # Upstream publishes no licence, which leaves the default "all rights
    # reserved" and so an unfree package by nixpkgs' definition.
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "xboxdownload";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
