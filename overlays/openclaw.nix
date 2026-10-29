# OpenClaw, the self-hosted AI assistant/agent, from nixos-unstable.
#
# nixpkgs 25.05 carries no openclaw attribute. Unstable marks it insecure
# (LLM-driven with full system access by default, so prompt injection is a
# risk); the opt-in is scoped to openclaw alone in this import rather than
# allowed system-wide.
{ inputs }:

final: prev: {
  openclaw =
    (import inputs.nixpkgs-unstable {
      system = prev.stdenv.hostPlatform.system;
      config.allowInsecurePredicate = pkg: (pkg.pname or "") == "openclaw";
    }).openclaw;
}
