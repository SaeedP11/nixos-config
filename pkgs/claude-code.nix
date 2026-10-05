# claude-code -- Anthropic's Claude Code CLI, from its own release bucket.
#
# Shadows the nixpkgs attribute through ../overlays: 25.05 carries 1.0.85,
# and even nixpkgs-unstable lags upstream by weeks, while Claude Code ships
# several releases a week.
#
# WHY THE NATIVE BINARY AND NOT THE npm PACKAGE. Upstream's own installer
# downloads this same single-file executable (Bun-compiled, glibc-linked),
# so it is what ~/.local/bin/claude ran before this file existed. It only
# needs its interpreter and libc rewritten by autoPatchelfHook. dontStrip
# because the JavaScript is appended to the ELF and stripping drops it.
#
# The built-in updater writes into ~/.local/share/claude and would move
# `claude` off this store path, so it is turned off; bumps happen here.
# To bump, read the version and its linux-x64 checksum with
#
#   B=https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases
#   curl -fsSL $B/latest
#   curl -fsSL $B/<version>/manifest.json   # platforms."linux-x64".checksum
#   nix hash convert --hash-algo sha256 --to sri <checksum>
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "claude-code";
  version = "2.1.289";

  src = fetchurl {
    url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${finalAttrs.version}/linux-x64/claude";
    hash = "sha256-oYa5nkqciDZs1J3y99rVbGH8MG7wFAsZ7mS3xCqNE0g=";
  };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/libexec/claude
    makeWrapper $out/libexec/claude $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1
    runHook postInstall
  '';

  meta = {
    description = "Agentic coding tool from Anthropic that lives in the terminal";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
