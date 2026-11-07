# antigravity-cli -- Google's Antigravity CLI (`agy`), from its release bucket.
#
# Shadows nixpkgs' antigravity-cli: 25.05 carries none, and nixos-unstable
# lags behind upstream (carrying 1.1.24 while upstream is 1.5.1+).
#
# To bump, check:
#   curl -fsSL https://storage.googleapis.com/antigravity-public/antigravity-cli/latest
#   curl -fsSL https://storage.googleapis.com/antigravity-public/antigravity-cli/<version>/manifest.json
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "1.5.1";
  buildId = "4523430503120896";
  wholeVersion = "${version}-${buildId}";

  throwSystem = throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}";

  sourceData = {
    x86_64-linux = fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/linux-x64/cli_linux_x64.tar.gz";
      hash = "sha256-KmTM/F9mecJTdp8HYGFK9d4E2Nwe7uybl1K6TI3ZIlA=";
    };
    aarch64-linux = fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/linux-arm/cli_linux_arm64.tar.gz";
      hash = "sha256-xDpQgxAG2Vp2N6qcrXAA/am5u0s+zoxTzGxQibklQuo=";
    };
    aarch64-darwin = fetchurl {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${wholeVersion}/darwin-arm/cli_mac_arm64.tar.gz";
      hash = "sha256-IXm6g+tUKewZJg0CIZars8vl5l4R4sLvLRmvVkwVWNs=";
    };
  };
in
stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  inherit version;

  src = sourceData.${stdenvNoCC.hostPlatform.system} or throwSystem;

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isElf [ autoPatchelfHook ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity $out/bin/agy
    ln -s agy $out/bin/antigravity
    runHook postInstall
  '';

  meta = {
    description = "Google's Go-based terminal user interface (TUI) agent client";
    homepage = "https://antigravity.google";
    changelog = "https://antigravity.google/changelog";
    license = lib.licenses.unfree;
    platforms = lib.attrNames sourceData;
    mainProgram = "agy";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
