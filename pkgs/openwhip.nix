# OpenWhip: a tray icon that, when clicked, throws a whip animation across the
# screen and sends Ctrl+C plus a rude word to whatever was focused, on the
# theory that Claude Code will then hurry up.
#
# Upstream (github.com/GitFrog1111/OpenWhip) ships as an npm global install
# that pulls its own Electron binary down at install time. That cannot work
# here, so this is a plain copy of the app's files plus a wrapper that runs
# nixpkgs' Electron against them. There is nothing to build: the app is four
# files of JavaScript and HTML with the sounds and icons beside them.
#
# node_modules is deliberately absent. package.json lists two dependencies,
# and neither is needed at runtime on this machine: `electron` is supplied by
# the wrapper, and `koffi` -- the FFI shim used to poke user32.dll -- is
# require()d only inside a `process.platform === 'win32'` branch.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  electron,
  wtype,
  xdotool,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openwhip";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "GitFrog1111";
    repo = "OpenWhip";
    # Upstream cuts no tags, so this is main as of 2026-09-11.
    rev = "83b976d7695934362b558b6340cb576c3b5656bb";
    hash = "sha256-9UFhQG5L3NNWx6IaKg11gQA0I+B1h6QfbxoMPV44TCg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # The Linux key-injection path is hardcoded to xdotool, which can only
  # reach X11 clients. This desktop is niri, where the terminal running
  # Claude Code is a native Wayland client, so xdotool would type into
  # nothing at all and the app's one feature would be dead on arrival.
  # wtype speaks virtual-keyboard-unstable-v1, which niri implements, so
  # prefer it whenever a Wayland session is present and keep xdotool for
  # the XWayland/X11 case. Both are on the wrapper's PATH.
  #
  # In wtype's argument grammar `--` means "the next argument is text even
  # if it starts with a dash", not "everything after this is text", so the
  # trailing `-k Return` after the phrase is still read as a key press.
  postPatch = ''
    substituteInPlace main.js \
      --replace-fail "function sendMacroLinux(text) {" ${lib.escapeShellArg ''
        function sendMacroLinux(text) {
          if (process.env.WAYLAND_DISPLAY) {
            execFile(
              'wtype',
              [
                '-M', 'ctrl', '-k', 'c', '-m', 'ctrl',
                '-s', '300',
                '--', text,
                '-k', 'Return',
              ],
              err => {
                if (err) {
                  console.warn('wayland macro failed:', err.message);
                }
              }
            );
            return;
          }
          return sendMacroLinuxX11(text);
        }

        function sendMacroLinuxX11(text) {
      ''}
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/openwhip
    # package.json comes along because Electron reads "main" out of it to
    # find the entry point of a directory it is pointed at.
    cp -r main.js preload.js overlay.html package.json icon sounds \
      $out/share/openwhip/

    makeWrapper ${lib.getExe electron} $out/bin/openwhip \
      --add-flags $out/share/openwhip \
      --prefix PATH : ${
        lib.makeBinPath [
          wtype
          xdotool
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Tray whip that interrupts Claude Code and tells it to go faster";
    homepage = "https://github.com/GitFrog1111/OpenWhip";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "openwhip";
  };
})
