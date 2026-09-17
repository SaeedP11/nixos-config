# rtk -- "Rust Token Killer", the CLI proxy ~/.claude/RTK.md tells Claude Code
# to route shell commands through so their output is filtered down before it
# reaches the model. A Claude Code hook rewrites `git status` into `rtk git
# status` transparently, which means a machine without rtk on PATH does not
# fail loudly: the hook's rewrite simply produces a command not found, or the
# hook declines to fire, and every session silently costs several times the
# tokens it should. Packaging it here is what makes that instruction true on
# a new machine rather than only on the one it was installed on by hand.
#
# WHY A PREBUILT RELEASE AND NOT rustPlatform.buildRustPackage. There is no
# rtk attribute in nixpkgs (and the name collides with reachingforthejack/rtk,
# "Rust Type Kit", which is a different program -- RTK.md's `rtk gain` check
# exists to tell them apart). Building from source would mean vendoring a
# Cargo.lock hash that has to be refreshed on every bump; the upstream
# release already publishes a static x86_64 musl build, so there is nothing
# to link against and nothing to patch.
#
# The musl tarball specifically: it is statically linked, so no
# autoPatchelfHook and no runtime dependency on this machine's glibc. Check
# with `ldd $out/bin/rtk`, which should report "not a dynamic executable".
#
# Pinned to the version that was installed by hand before this file existed,
# so the move into the repository was not also a silent upgrade. To bump it,
# change `version` and refresh `hash` with
#
#   nix store prefetch-file --name rtk-<version>.tar.gz \
#     https://github.com/rtk-ai/rtk/releases/download/v<version>/rtk-x86_64-unknown-linux-musl.tar.gz
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "rtk";
  version = "0.48.0";

  src = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${finalAttrs.version}/rtk-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-5OZQ+hZ3wN4vaDmmBA17F/MS0y8WPEArda9w6eWvGpE=";
  };

  # The tarball holds the bare `rtk` binary with no directory around it, so
  # the default unpackPhase has no single directory to descend into and
  # would fail. "." keeps it in the build root.
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 rtk $out/bin/rtk
    runHook postInstall
  '';

  meta = {
    description = "Token-optimized CLI proxy that filters shell output for coding agents";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.mit;
    mainProgram = "rtk";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
