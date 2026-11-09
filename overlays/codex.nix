# OpenAI Codex CLI (`codex`) from nixos-unstable.
#
# nixpkgs 25.05 carries an obsolete Node-based pre-release (0.1.x), while
# nixos-unstable carries the modern Rust-based CLI (0.153.x+) with ripgrep,
# bubblewrap sandboxing, and shell completions.
#
# Provides both `codex` and `codex-cli` binary symlinks and package attributes.
{ inputs }:

final: prev: {
  codex =
    let
      pkg = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.codex;
    in
    prev.symlinkJoin {
      name = pkg.name;
      paths = [ pkg ];
      postBuild = ''
        ln -s codex $out/bin/codex-cli
      '';
      passthru = (pkg.passthru or { }) // {
        unwrapped = pkg;
      };
      meta = pkg.meta;
    };

  codex-cli = final.codex;
}
