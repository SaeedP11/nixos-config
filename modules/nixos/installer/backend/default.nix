# The installer backend: the root-run CLI the Quickshell installer drives.
# It probes disks, validates an install plan, and runs the install in phases
# while streaming JSON-lines events (see
# specs/003-quickshell-os-installer/contracts/backend-cli.md).
#
# Stdlib-only Python, so there is nothing to lock; the tools it shells out to
# are put on PATH by the wrapper so it works the same on the live ISO and from
# `nix run`. Exposed as pkgs.installer-backend by ../../../../pkgs.
{
  lib,
  python3Packages,
  makeWrapper,
  util-linux,
  e2fsprogs,
  btrfs-progs,
  cryptsetup,
  dosfstools,
  ntfs3g,
  parted,
  gptfdisk,
  nixos-install-tools,
  mkpasswd,
  curl,
  networkmanager,
  coreutils,
}:

python3Packages.buildPythonApplication {
  pname = "installer-backend";
  version = "0.1.0";
  pyproject = false;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = ./installer_backend;
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/${python3Packages.python.sitePackages}
    cp -r installer_backend $out/${python3Packages.python.sitePackages}/
    makeWrapper ${python3Packages.python.interpreter} $out/bin/installer-backend \
      --add-flags "-m installer_backend" \
      --set PYTHONPATH $out/${python3Packages.python.sitePackages} \
      --prefix PATH : ${
        lib.makeBinPath [
          util-linux
          e2fsprogs
          btrfs-progs
          cryptsetup
          dosfstools
          ntfs3g
          parted
          gptfdisk
          nixos-install-tools
          mkpasswd
          curl
          networkmanager
          coreutils
        ]
      }
    runHook postInstall
  '';

  meta.mainProgram = "installer-backend";
}
