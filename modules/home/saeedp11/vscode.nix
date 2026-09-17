# Visual Studio Code: the editor, its settings, its keybindings, and the
# extensions nixpkgs carries.
#
# The package used to be one line in ./packages.nix, which installed the
# editor and nothing else -- every setting below, and all twenty-nine
# extensions, were placed by hand and lived only in ~/.config/Code/User and
# ~/.vscode/extensions. That is the largest single piece of this account's
# configuration that a fresh install would not have reproduced.
#
# THE TRADE-OFF, which is the same one ./xdg.nix documents for
# mimeapps.list. Home Manager writes settings.json and keybindings.json as
# read-only store symlinks, so the Settings UI and the keyboard-shortcuts
# editor can no longer save: VS Code reports a write failure instead of
# silently doing nothing, which is at least visible. Change the setting
# here and rebuild. This is deliberate -- these two files are edited
# occasionally and by hand, unlike the runtime-rewritten files listed in
# ./default.nix that must stay unmanaged.
#
# EXTENSIONS ARE DELIBERATELY HALF-MANAGED. `mutableExtensionsDir` is left
# at its default of true, which means the extensions listed here are
# symlinked into ~/.vscode/extensions while anything installed from the
# Marketplace stays put and keeps updating itself. That matters because the
# ones that are *not* in nixpkgs are the ones that cannot be: Anthropic's
# claude-code, OpenAI's chatgpt, wakatime, omnicopilot, nuxtr, the vue
# snippets and the Chrome/Edge devtools bridges are proprietary Marketplace
# builds with no nixpkgs attribute, and vendoring them would mean pinning a
# hash per extension and refreshing it by hand forever. Declaring the
# open-source two thirds gets the toolchain -- formatters, linters and
# language servers that the settings below name by id -- onto a new machine
# automatically, and leaves the rest a one-off sign-in-and-install.
#
# A consequence worth knowing about: nixpkgs' copy of an extension is often
# older than the one the Marketplace has already self-updated to here (25.05
# carries copilot 1.322.0 against the installed 1.388.0). The two land in
# differently-named directories and VS Code loads the higher version, so the
# nixpkgs copy is inert on a machine that already has a newer one and is the
# starting point on a machine that does not. That is the intended
# behaviour, not a conflict to resolve.
{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;

    profiles.default = {
      # Every extension below is referenced by an id in userSettings, or
      # supplies a language server the editor is useless without. Ordered
      # as nixpkgs names them.
      extensions = with pkgs.vscode-extensions; [
        # Formatters named as editor.defaultFormatter for a language.
        esbenp.prettier-vscode # html, css, and the global default
        foxundermoon.shell-format # shellscript, properties
        redhat.vscode-yaml # yaml
        tamasfe.even-better-toml # toml
        ms-vscode.cpptools # cpp
        rust-lang.rust-analyzer # rust, and the Rust language server
        vue.volar # vue, and the Vue language server

        # Linters.
        dbaeumer.vscode-eslint
        stylelint.vscode-stylelint

        # Git. gitlens is configured in userSettings below; git-graph is
        # the history view.
        eamodio.gitlens
        mhutchie.git-graph

        # Language support with no formatter attached.
        bbenoist.nix # this repository
        bradlc.vscode-tailwindcss
        graphql.vscode-graphql-syntax

        # Assistants. Not claude-code, chatgpt or omnicopilot -- see the
        # note above about Marketplace-only builds.
        github.copilot
        github.copilot-chat
        continue.continue

        streetsidesoftware.code-spell-checker
      ];

      keybindings = [
        {
          key = "alt+d";
          command = "duplicate.execute";
        }
        {
          key = "ctrl+shift+d";
          command = "editor.action.duplicateSelection";
        }
        {
          key = "ctrl+alt+u";
          command = "editor.action.transformToUppercase";
        }
        {
          key = "ctrl+alt+l";
          command = "editor.action.transformToLowercase";
        }
        {
          key = "ctrl+m";
          command = "extension.toggleCase.commands";
        }
      ];

      userSettings = {
        # Editor
        "editor.fontSize" = 16;
        "editor.fontFamily" = "'Gintronic','Droid Sans Mono', 'monospace', 'Font Awesome 6'";
        "editor.minimap.enabled" = false;
        "editor.detectIndentation" = false;
        "editor.multiCursorModifier" = "ctrlCmd";
        "editor.gotoLocation.multipleDefinitions" = "goto";
        # Default: adds # and $ and drops _ , so word-wise motion stops at
        # shell variables and treats snake_case as one word.
        "editor.wordSeparators" = "`~!@#%^&*()-=+[{]}\\|;:'\",.<>/?";
        "editor.defaultFormatter" = "esbenp.prettier-vscode";

        # Per-language formatters. The ids here are why the extensions
        # above are installed.
        "[javascript]"."editor.defaultFormatter" = "vscode.typescript-language-features";
        "[typescript]"."editor.defaultFormatter" = "vscode.typescript-language-features";
        "[json]"."editor.defaultFormatter" = "vscode.json-language-features";
        "[jsonc]"."editor.defaultFormatter" = "vscode.json-language-features";
        "[html]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
        "[css]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
        "[vue]"."editor.defaultFormatter" = "Vue.volar";
        "[yaml]"."editor.defaultFormatter" = "redhat.vscode-yaml";
        "[toml]"."editor.defaultFormatter" = "tamasfe.even-better-toml";
        "[rust]"."editor.defaultFormatter" = "rust-lang.rust-analyzer";
        "[cpp]"."editor.defaultFormatter" = "ms-vscode.cpptools";
        "[php]"."editor.defaultFormatter" = "bmewburn.vscode-intelephense-client";
        "[proto3]"."editor.defaultFormatter" = "zxh404.vscode-proto3";
        "[sql]"."editor.defaultFormatter" = "cweijan.vscode-mysql-client2";
        "[shellscript]"."editor.defaultFormatter" = "foxundermoon.shell-format";
        "[properties]"."editor.defaultFormatter" = "foxundermoon.shell-format";
        "[python]"."editor.formatOnType" = true;
        "[graphql]" = { };
        "[dockercompose]" = {
          "editor.insertSpaces" = true;
          "editor.tabSize" = 2;
          "editor.autoIndent" = "advanced";
        };

        # Prettier
        "prettier.useEditorConfig" = false;
        "prettier.singleQuote" = true;
        "prettier.singleAttributePerLine" = true;
        "prettier.bracketSpacing" = false;
        "prettier.bracketSameLine" = true;
        "prettier.useTabs" = true;
        "prettier.configPath" = ".prettierrc";

        # Workbench
        "workbench.iconTheme" = "vira-icons-ocean";
        "workbench.editor.enablePreview" = false;
        "workbench.editor.splitInGroupLayout" = "vertical";
        "workbench.editor.empty.hint" = "hidden";
        "workbench.editorAssociations" = {
          "*.ipynb" = "jupyter.notebook.ipynb";
          "*.svg" = "default";
        };
        "viraTheme.accent" = "Lime";

        # Diffs
        "diffEditor.renderSideBySide" = false;
        "diffEditor.ignoreTrimWhitespace" = false;
        "diffEditor.hideUnchangedRegions.enabled" = true;

        # Git
        "git.autofetch" = true;
        "git.confirmSync" = false;
        "git.ignoreRebaseWarning" = true;
        "git.openRepositoryInParentFolders" = "never";
        "gitlens.gitCommands.skipConfirmations" = [
          "fetch:command"
          "switch:command"
          "stash-push:command"
        ];
        "gitlens.advanced.messages" = {
          "suppressCommitHasNoPreviousCommitWarning" = true;
          "suppressLineUncommittedWarning" = true;
        };

        # Terminal. The integrated terminal keeps its own font; the
        # external one is alacritty, the same terminal
        # ../../nixos/desktop/niri.nix makes the session default and
        # ./xdg.nix lists first in xdg-terminals.list.
        "terminal.integrated.fontFamily" = "monospace";
        # Carried over verbatim, and dead: nothing in this configuration
        # installs zsh, so VS Code falls back to $SHELL, which
        # ../../nixos/users.nix sets to fish. Kept rather than corrected so
        # that moving these settings into the repository changed none of
        # them; set it to "fish" if the fallback ever stops being silent.
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "terminal.external.linuxExec" = "alacritty";
        "terminal.explorerKind" = "external";
        "terminal.sourceControlRepositoriesKind" = "external";

        # TypeScript/JavaScript
        "typescript.updateImportsOnFileMove.enabled" = "always";
        "javascript.updateImportsOnFileMove.enabled" = "always";

        # Assistants
        "github.copilot.enable" = {
          "*" = true;
          "plaintext" = false;
          "markdown" = false;
          "scminput" = false;
          "rust" = true;
        };
        "omnicopilot.baseUrl" = "https://omniroute.sp11.ir";
        "claudeCode.preferredLocation" = "panel";
        "tabnine.experimentalAutoImports" = true;

        # Misc extensions
        "todo-tree.general.tags" = [
          "BUG"
          "HACK"
          "FIXME"
          "TODO"
          "XXX"
        ];
        "liveServer.settings.donotVerifyTags" = true;
        "liveServer.settings.donotShowInfoMsg" = true;
        "vscode-edge-devtools.mirrorEdits" = true;
        "database-client.autoSync" = true;
        "mdb.mcp.server" = "prompt";
        "atomKeymap.promptV3Features" = true;

        "explorer.confirmDelete" = false;
        "redhat.telemetry.enabled" = true;
      };
    };
  };
}
