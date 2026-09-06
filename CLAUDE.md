# NixOS Project Instructions

## Scope

This repository is the source of truth for this NixOS configuration.

Work autonomously and make the smallest change that fully solves the user's task.

## File Scope

Allowed by default:

* Current repository and all subdirectories
* `~/.config`
* `~/.local`
* `~/.local/share`
* `~/.local/state`

Use `~/.config` and `~/.local` only when relevant to the task.

Do not inspect or modify unrelated locations outside these paths.

Never perform filesystem-wide searches such as:

```bash
find /
fd /
rg /
locate
updatedb
```

If information outside the allowed scope is genuinely required, explain why before accessing it.

Never modify system files outside the repository unless explicitly requested.

## Repository First

Prefer repository-managed configuration over manual changes.

Before creating a new module, package, overlay, helper, or configuration file:

1. Check whether an existing solution can be reused.
2. Follow existing project structure and conventions.
3. Prefer extending existing configuration over introducing parallel solutions.

The repository is authoritative over live user configuration.

If equivalent configuration exists in both the repository and `~/.config` or `~/.local`, prefer the repository version.

## Declarative NixOS

Prefer:

* NixOS modules
* Home Manager
* Flakes
* Overlays
* Package definitions
* Reproducible configuration

Avoid:

* One-off manual fixes
* Imperative setup
* Editing generated files
* Configuration drift

Prefer solutions that survive rebuilds, upgrades, and machine migration.

## Investigation

Match investigation depth to task complexity.

### Simple task

Inspect the relevant file(s), edit, and perform lightweight validation.

### Non-trivial task

Understand dependencies and impact, inspect relevant source/configuration, then edit and validate.

Do not read large files, directories, or unrelated modules without a reason.

Do not repeat searches or reread unchanged information when the existing context is sufficient.

## code-review-graph MCP

When available, use `code-review-graph` for non-trivial repository exploration and impact analysis.

Prefer graph tools for:

* semantic discovery
* dependency/relationship tracing
* impact analysis
* architecture questions
* change review

Typical tools:

* `semantic_search_nodes_tool`
* `query_graph_tool`
* `get_impact_radius_tool`
* `get_affected_flows_tool`
* `detect_changes_tool`
* `get_review_context_tool`
* `get_architecture_overview_tool`
* `list_communities_tool`
* `refactor_tool`

Use the graph to narrow scope, then verify findings in the actual source.

Never modify code from graph output alone.

If graph data conflicts with source, source wins.

An empty graph result does not prove that something does not exist.

For trivial changes, skip graph exploration.

## Source Verification

For non-trivial changes, inspect the implementation and relevant validation paths before concluding.

Verify actual source when changing:

* behavior
* module composition
* NixOS options
* Home Manager
* overlays
* package definitions
* flake inputs/outputs
* compatibility
* recovery/fallback logic

Static graph information never replaces source inspection.

## Validation

Use the lightest sufficient validation.

Prefer targeted checks over full builds.

For Nix flakes, use appropriate checks such as:

```bash
nix flake check
```

only when relevant.

Do not perform a full system rebuild unless requested or necessary.

Never claim validation was performed unless it was actually executed.

## Change Discipline

Keep changes:

* minimal
* focused
* declarative
* consistent
* reversible

Do not refactor unrelated code.

Do not make unnecessary formatting changes.

Do not rewrite working configuration without a concrete reason.

## Safety

Do not access:

* SSH private keys
* passwords or password stores
* browser credentials
* shell history
* unrelated personal files
* unrelated directories

Do not expose secrets in responses.

## Autonomy

Solve tasks without unnecessary clarification.

Use reasonable assumptions based on repository conventions.

Ask the user only when:

* required information is genuinely missing;
* the requested action is ambiguous in a way that materially affects the result;
* or the task would require leaving the approved scope.

Otherwise proceed autonomously.

## Response Style

Keep responses concise and implementation-focused.

After completing a task, report only:

* files changed
* what changed
* validation performed
* important issues, if any
