# Escrcpy: an Electron front end to scrcpy for mirroring and controlling
# Android phones over USB or wireless debugging, several at once.
#
# nixpkgs carries no escrcpy (neither 25.05 nor unstable), and upstream is an
# electron-vite app whose source build would mean pinning its whole pnpm tree,
# so this wraps the official AppImage. The hash is upstream's own, taken from
# the release's latest-linux.yml rather than a local prefetch.
#
# The AppImage bundles its own adb and scrcpy, but ../modules/nixos/programs/
# android.nix installs both from nixpkgs as well. Point Escrcpy at those in
# Preferences -> General (adb path /run/current-system/sw/bin/adb, scrcpy path
# /run/current-system/sw/bin/scrcpy) so the phone always talks to the same adb
# server as the shell and scrcpy follows nixpkgs updates.
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "escrcpy";
  version = "3.2.0";

  src = fetchurl {
    url = "https://github.com/viarotel-org/escrcpy/releases/download/v${version}/Escrcpy-${version}-linux-x86_64.AppImage";
    hash = "sha512-+KduEFJrag9YFIpL5BRSMCGdThzURfG4WeEXYbqyt7rxCp6At907G0ZZFHQmKF0IlefYPNP4PawhztB20UB/XQ==";
  };

  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # The launcher entry and icons electron-builder put at the image root and
  # under usr/share, with Exec pointed at the wrapper instead of AppRun.
  extraInstallCommands = ''
    install -Dm444 ${contents}/${pname}.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${contents}/usr/share/icons $out/share
  '';

  meta = {
    description = "Graphical scrcpy front end for Android screen mirroring and control";
    homepage = "https://github.com/viarotel-org/escrcpy";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
