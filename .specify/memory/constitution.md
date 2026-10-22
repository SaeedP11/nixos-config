<!--
Sync Impact Report
- Version change: (unfilled template) → 1.0.0
- Modified principles: n/a (initial adoption)
- Added principles:
  I. Declarative and Reproducible
  II. Repository Is the Source of Truth
  III. Reuse and Extend Before Adding
  IV. Minimal, Focused, Reversible Changes
  V. Document the Why In Place
  VI. One Cohesive Desktop Shell
- Added sections: Scope and Safety Constraints; Development Workflow and Quality Gates; Governance
- Removed sections: none
- Templates: not modified (dependent templates read this file at runtime)
- Deferred TODOs: none
-->

# saeedp11 NixOS Configuration Constitution

## Core Principles

### I. Declarative and Reproducible

Every change to system or user configuration MUST be expressed declaratively in this flake:
NixOS modules, Home Manager modules, overlays, or package definitions under `pkgs/`.

- One-off imperative fixes, hand-edited live files and manual setup steps MUST NOT be the
  solution of record.
- A change MUST survive `nixos-rebuild switch`, upgrades and migration to a new machine.
- Generated files (for example the rendered `~/.config/niri/config.kdl`) MUST be changed through
  their source template, never edited directly.

Rationale: the configuration is only worth having if `nixos-rebuild switch --flake .#<host>`
reproduces the whole desktop.

### II. Repository Is the Source of Truth

This repository is authoritative over live state in `~/.config` and `~/.local`.

- Where the repository and live configuration disagree, the repository version wins.
- Files intentionally left unmanaged (because a program rewrites them at runtime) MUST be listed
  in the README's "What is and is not managed here" section with the reason.
- Deliberate omissions from reproduction (secrets, licences, large media) MUST be documented in
  the README rather than silently left out.

Rationale: a single owner per file is what prevents configuration drift.

### III. Reuse and Extend Before Adding

Before creating a new module, package, overlay, helper or configuration file, existing solutions
MUST be checked and reused or extended where they fit.

- New code MUST follow the existing layout: system scope in `modules/nixos/<area>/`, user scope in
  `modules/home/saeedp11/`, packages in `pkgs/` exposed through `overlays/`, per-host choices in
  `hosts/<name>/` and the `apps.*` switches in `modules/nixos/apps.nix`.
- Parallel solutions for the same job (two bars, two notification daemons, two handlers for one
  MIME type) MUST NOT coexist without a written reason.

Rationale: one obvious place for each concern keeps a three-host configuration navigable.

### IV. Minimal, Focused, Reversible Changes

Each change MUST be the smallest one that fully solves the task.

- Unrelated refactors, renames and formatting churn MUST NOT be bundled into a change.
- Working configuration MUST NOT be rewritten without a concrete, stated reason.
- Removing a program MUST also remove what depends on it: MIME associations in `xdg.nix`,
  launcher or bar bindings, niri binds, and comments that describe it.

Rationale: small, self-contained changes are easy to review, bisect and revert.

### V. Document the Why In Place

Non-obvious decisions MUST be explained in a comment next to the code they govern: why this
package or option was chosen, what it replaced, and what breaks without it.

- Comments MUST describe current behaviour; when a change makes a comment untrue, the comment
  MUST be updated in the same change.
- Cross-references between modules MUST use relative paths so they stay valid.

Rationale: this configuration is maintained by one person and by agents across sessions; the
reasoning has to live with the code, not in memory.

### VI. One Cohesive Desktop Shell

The niri session's desktop UI is the Quickshell config in `modules/home/saeedp11/quickshell/`.

- New desktop surfaces (panels, popouts, widgets, small utilities that fit a popout) SHOULD be
  built there before adding a standalone application.
- Quickshell code MUST follow its structure: singletons in `services/`, surfaces in `modules/`,
  shared controls in `widgets/`, and colours, spacing and timing from `config/Theme.qml` (which
  follows the wallust palette) rather than hard-coded values.
- A new popout MUST be registered in `services/Panels.qml`, `modules/popouts/PopoutLayer.qml` and
  the panel list in `shell.qml`, and be reachable through `qs -c shell ipc call panel toggle`.

Rationale: one shell with one theme source gives a consistent desktop that follows the live
palette and dark/light switch.

## Scope and Safety Constraints

- Work is confined to this repository and, only when relevant, `~/.config`, `~/.local`,
  `~/.local/share` and `~/.local/state`. Filesystem-wide searches MUST NOT be run.
- System files outside the repository MUST NOT be modified unless explicitly requested.
- SSH and GPG private keys, password stores, browser credentials, shell history and unrelated
  personal files MUST NOT be read. Secrets MUST NOT appear in the repository or in responses.
- Unfree packages are allowed only through the policy in `modules/nixos/core/nix.nix`.

## Development Workflow and Quality Gates

- Investigation depth MUST match task complexity; non-trivial changes to behaviour, module
  composition, options, overlays, packages or flake inputs/outputs MUST be verified against the
  actual source, not inferred from graph or memory alone.
- Validation MUST use the lightest sufficient check (evaluating or building the affected
  attribute, `nix flake check`, `nix fmt`). A full system rebuild is run only when requested or
  necessary.
- Validation MUST NOT be claimed unless it was actually executed; failures are reported with
  their output.
- Nix code MUST be formatted with nixfmt-rfc-style (`nix fmt`).
- Commit messages MUST use the conventional-commit style with the affected path as the scope,
  e.g. `feat(modules/nixos/programs/gui.nix): ...`.
- New hosts MUST be `git add`ed before building, since the flake only sees tracked files.

## Governance

This constitution supersedes ad-hoc practice for this repository. `CLAUDE.md` holds runtime
guidance for agents and MUST stay consistent with it; on conflict, this document wins until
`CLAUDE.md` is amended.

- Amendments are made by editing this file, with a Sync Impact Report at the top describing the
  change.
- Versioning follows semantic versioning: MAJOR for removing or redefining a principle, MINOR for
  adding a principle or section or materially expanding guidance, PATCH for clarifications.
- Specs, plans and reviews produced with Spec Kit MUST check compliance with these principles and
  justify any deviation explicitly.

**Version**: 1.0.0 | **Ratified**: 2026-10-22 | **Last Amended**: 2026-10-22
