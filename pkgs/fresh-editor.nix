# fresh -- terminal text editor with LSP support and TypeScript plugins.
#
# Not in nixpkgs 25.05 at all, and nixpkgs-unstable's fresh-editor trails the
# upstream release, so this follows ./rtk.nix: the static x86_64 musl build
# from the GitHub release, with nothing to link against or patch.
#
# To bump, change `version` and refresh `hash` with
#
#   nix store prefetch-file \
#     https://github.com/sinelaw/fresh/releases/download/v<version>/fresh-editor-x86_64-unknown-linux-musl.tar.gz
{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fresh-editor";
  version = "0.5.2";

  src = fetchurl {
    url = "https://github.com/sinelaw/fresh/releases/download/v${finalAttrs.version}/fresh-editor-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-Ld4dTn9ZVv2/9cNlYVJcmM7OJCLihJN8iX/y6xfEA30=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm755 fresh $out/bin/fresh
    install -Dm644 fresh.desktop $out/share/applications/fresh.desktop
    cp -r icons $out/share/icons
    runHook postInstall
  '';

  meta = {
    description = "Terminal-based text editor with LSP support and TypeScript plugins";
    homepage = "https://github.com/sinelaw/fresh";
    license = lib.licenses.gpl2Only;
    mainProgram = "fresh";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
